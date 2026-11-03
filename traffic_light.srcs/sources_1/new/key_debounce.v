// =============================================================
// 文件: key_debounce.v
// 板卡: 米联客 MLK-F3-CZ02-7020 (仅 KEY4/KEY5 两个 PL 按键)
// 功能: 两按键消抖 + 多功能设置键识别
//       KEY4: 行人请求 —— 按下沿输出单周期脉冲
//       KEY5: 短按(<1s)释放时输出 set_pulse(切换配置目标);
//             长按(≥1s)期间每 0.5s 输出一次 inc_pulse(时长+1)
// 说明: 20ms 消抖; 按键低电平有效(上拉输入, 按下接地)
// =============================================================
module key_debounce #(
    parameter CLK_FREQ = 100_000_000   // 100MHz
)(
    input  clk,
    input  rst_n,
    input  key_ped,     // KEY4 行人请求
    input  key_set,     // KEY5 设置键
    output reg ped_pulse,
    output reg set_pulse,
    output reg inc_pulse
);

    // 20ms 消抖计数阈值
    localparam DEB_CYCLES = CLK_FREQ / 50;      // 2_000_000 @100MHz
    localparam HOLD_1S    = CLK_FREQ;           // 长按判定: 1s
    localparam HALF_SEC   = CLK_FREQ / 2;       // 长按连发间隔: 0.5s

    // ---------------- KEY4: 消抖 + 按下沿 ----------------
    reg [1:0]  ped_sync;
    reg        ped_level, ped_prev;
    reg [20:0] ped_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ped_sync  <= 2'b11;
            ped_level <= 1'b1;
            ped_prev  <= 1'b1;
            ped_cnt   <= 21'd0;
        end else begin
            ped_sync  <= {ped_sync[0], key_ped};
            ped_prev  <= ped_level;
            if (ped_sync[1] == ped_level)
                ped_cnt <= 21'd0;
            else begin
                ped_cnt <= ped_cnt + 1'b1;
                if (ped_cnt >= DEB_CYCLES - 1) begin
                    ped_level <= ped_sync[1];
                    ped_cnt   <= 21'd0;
                end
            end
        end
    end

    wire ped_press = ped_prev & ~ped_level;    // 按下沿

    // 行人请求脉冲输出（按下沿展开为单周期脉冲）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ped_pulse <= 1'b0;
        else
            ped_pulse <= ped_press;
    end

    // ---------------- KEY5: 消抖 + 短按/长按识别 ----------------
    reg [1:0]  set_sync;
    reg        set_level, set_prev;
    reg [20:0] set_cnt;
    reg [26:0] hold_cnt;
    reg        long_mode;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            set_sync  <= 2'b11;
            set_level <= 1'b1;
            set_prev  <= 1'b1;
            set_cnt   <= 21'd0;
        end else begin
            set_sync  <= {set_sync[0], key_set};
            set_prev  <= set_level;
            if (set_sync[1] == set_level)
                set_cnt <= 21'd0;
            else begin
                set_cnt <= set_cnt + 1'b1;
                if (set_cnt >= DEB_CYCLES - 1) begin
                    set_level <= set_sync[1];
                    set_cnt   <= 21'd0;
                end
            end
        end
    end

    wire set_press   = set_prev & ~set_level;  // 按下沿
    wire set_release = ~set_prev & set_level;  // 释放沿

    // 按住时长测量与连发
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hold_cnt  <= 27'd0;
            long_mode <= 1'b0;
            set_pulse <= 1'b0;
            inc_pulse <= 1'b0;
        end else begin
            set_pulse <= 1'b0;
            inc_pulse <= 1'b0;

            if (set_press) begin
                hold_cnt  <= 27'd0;      // 新的一次按下
                long_mode <= 1'b0;
            end else if (!set_level) begin
                // 按住中
                hold_cnt <= hold_cnt + 1'b1;
                if (!long_mode) begin
                    if (hold_cnt >= HOLD_1S - 1) begin
                        long_mode <= 1'b1;   // 达到 1s, 进入长按模式
                        inc_pulse <= 1'b1;   // 立即 +1 一次
                        hold_cnt  <= 27'd0;
                    end
                end else begin
                    if (hold_cnt >= HALF_SEC - 1) begin
                        inc_pulse <= 1'b1;   // 每 0.5s 连发 +1
                        hold_cnt  <= 27'd0;
                    end
                end
            end else begin
                // 已释放
                if (set_release && !long_mode)
                    set_pulse <= 1'b1;       // 短按: 切换配置目标
            end
        end
    end

endmodule
