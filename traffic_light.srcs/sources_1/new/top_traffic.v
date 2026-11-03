// =============================================================
// 文件: top_traffic.v
// 板卡: 米联客 MLK-F3-CZ02-7020
// 功能: 可配置智能交通信号灯系统顶层
//
// 硬件适配说明（依据板卡手册/原理图 P13_LED&KEY）:
//   - 板上无数码管: 倒计时改用 LED4/LED6/LED7/LED8 以二进制显示(1~15)
//   - PL 按键只有 KEY4/KEY5 两个:
//       KEY4 = 行人过街请求(绿灯期按下立即切黄灯)
//       KEY5 = 设置键: 短按(<1s)循环选择配置目标(红/黄/绿),
//                      长按(≥1s)期间每 0.5s 将目标时长 +1 (1~15 回绕)
//   - PL 时钟 100MHz; LED 低电平点亮
//   - 无外部复位: 内部上电复位(POR), 比特流加载后自动启动
// =============================================================
module top_traffic #(
    parameter CLK_FREQ    = 100_000_000,  // 100MHz
    parameter RED_TIME    = 8'd10,        // 红灯默认时长(秒), 1~15
    parameter YELLOW_TIME = 8'd5,         // 黄灯默认时长(秒), 1~15
    parameter GREEN_TIME  = 8'd15         // 绿灯默认时长(秒), 1~15
)(
    input        clk,      // 100MHz PL 时钟 (H16)
    input        key_ped,  // KEY4 (R19) 行人请求, 按下为低
    input        key_set,  // KEY5 (T19) 设置键, 按下为低
    output [6:0] led       // 低电平点亮: [0]=LED1红 [1]=LED2黄 [2]=LED3绿
                           //            [3]~[6]=LED4/6/7/8 倒计时二进制bit0~3
);

    // ---------- 内部上电复位 (无外部复位按键) ----------
    reg [7:0]  por_cnt = 8'd0;
    reg        rst_n   = 1'b0;
    always @(posedge clk) begin
        if (!por_cnt[7])
            por_cnt <= por_cnt + 1'b1;
        else
            rst_n <= 1'b1;   // 约 2.6us 后释放复位
    end

    // ---------- 按键处理 ----------
    wire ped_pulse, set_pulse, inc_pulse;
    key_debounce #(
        .CLK_FREQ(CLK_FREQ)
    ) u_key (
        .clk      (clk),
        .rst_n    (rst_n),
        .key_ped  (key_ped),
        .key_set  (key_set),
        .ped_pulse(ped_pulse),
        .set_pulse(set_pulse),
        .inc_pulse(inc_pulse)
    );

    // ---------- 各灯时长配置 (1~15 秒) ----------
    localparam MAX_TIME = 8'd15;

    reg [7:0] red_time    = RED_TIME;
    reg [7:0] yellow_time = YELLOW_TIME;
    reg [7:0] green_time  = GREEN_TIME;

    // 配置目标: 0=红 1=黄 2=绿, KEY5 短按循环切换
    reg [1:0] set_target;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            set_target <= 2'd0;
        else if (set_pulse)
            set_target <= (set_target == 2'd2) ? 2'd0 : set_target + 1'b1;
    end

    // KEY5 长按: 当前目标时长 +1 (15 后回绕到 1)
    always @(posedge clk) begin
        if (inc_pulse) begin
            case (set_target)
                2'd0:    red_time    <= (red_time    >= MAX_TIME) ? 8'd1 : red_time    + 1'b1;
                2'd1:    yellow_time <= (yellow_time >= MAX_TIME) ? 8'd1 : yellow_time + 1'b1;
                default: green_time  <= (green_time  >= MAX_TIME) ? 8'd1 : green_time  + 1'b1;
            endcase
        end
    end

    // ---------- 交通灯主控 ----------
    wire [7:0] counter;
    wire [2:0] light;   // light[0]=红 light[1]=黄 light[2]=绿 (高电平有效)

    traffic_ctrl #(
        .CLK_FREQ    (CLK_FREQ),
        .RED_TIME    (RED_TIME),
        .YELLOW_TIME (YELLOW_TIME),
        .GREEN_TIME  (GREEN_TIME)
    ) u_ctrl (
        .clk        (clk),
        .rst_n      (rst_n),
        .ped_pulse  (ped_pulse),
        .red_time   (red_time),
        .yellow_time(yellow_time),
        .green_time (green_time),
        .led        (light),
        .counter    (counter)
    );

    // ---------- 输出映射 (LED 低电平点亮) ----------
    // led[0]=红 led[1]=黄 led[2]=绿; led[3]~led[6]=剩余秒数二进制 bit0~3
    assign led = ~{counter[3], counter[2], counter[1], counter[0],
                   light[2],  light[1],  light[0]};

endmodule
