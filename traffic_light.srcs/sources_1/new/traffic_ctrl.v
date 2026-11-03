// =============================================================
// 文件: traffic_ctrl.v
// 板卡: 米联客 MLK-F3-CZ02-7020 (PL 时钟 100MHz)
// 功能: 交通灯主控制器（三状态 FSM + 1Hz 秒时基 + 行人请求优先）
// 时序: 绿 -> 黄 -> 红 -> 绿 循环
//       绿灯期间收到行人请求(ped_pulse)立即切换黄灯（缩短绿灯）；
//       红灯期间行人请求被忽略（当前方向本就禁止通行）。
//       各相位时长 1~15 秒可动态修改，修改后立即刷新当前倒计时。
// =============================================================
module traffic_ctrl #(
    parameter CLK_FREQ    = 100_000_000,  // 100MHz
    parameter RED_TIME    = 8'd10,        // 红灯默认时长(秒), 1~15
    parameter YELLOW_TIME = 8'd5,         // 黄灯默认时长(秒), 1~15
    parameter GREEN_TIME  = 8'd15         // 绿灯默认时长(秒), 1~15
)(
    input        clk,        // 100MHz 系统时钟
    input        rst_n,      // 低电平复位(内部上电复位)
    input        ped_pulse,  // 行人请求脉冲（单周期）
    input  [7:0] red_time,   // 红灯时长(秒), 1~15
    input  [7:0] yellow_time,// 黄灯时长(秒), 1~15
    input  [7:0] green_time, // 绿灯时长(秒), 1~15
    output reg [2:0] led,    // led[0]=红, led[1]=黄, led[2]=绿 (高电平有效)
    output reg [7:0] counter // 当前相位剩余秒数（低4位送LED二进制显示）
);

    // 状态编码
    localparam S_RED    = 2'd0;
    localparam S_GREEN  = 2'd1;
    localparam S_YELLOW = 2'd2;

    reg [1:0]  state;

    // 1Hz 秒时基
    reg [26:0] div_cnt;
    wire tick_1s = (div_cnt == CLK_FREQ - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            div_cnt <= 27'd0;
        else
            div_cnt <= tick_1s ? 27'd0 : div_cnt + 1'b1;
    end

    // 参数修改检测（用于修改后立即刷新倒计时）
    reg [7:0] red_q, yel_q, grn_q;
    always @(posedge clk) begin
        red_q <= red_time;
        yel_q <= yellow_time;
        grn_q <= green_time;
    end

    // 主状态机：每秒倒计时，计到 0 切换相位
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= S_RED;
            counter <= RED_TIME;
        end else begin
            // 对应相位时长被修改时，立即以新值刷新倒计时
            if (state == S_RED    && red_time    != red_q) counter <= red_time;
            if (state == S_GREEN  && green_time  != grn_q) counter <= green_time;
            if (state == S_YELLOW && yellow_time != yel_q) counter <= yellow_time;

            case (state)
                S_RED: begin
                    if (tick_1s) begin
                        if (counter <= 8'd1) begin
                            state   <= S_GREEN;
                            counter <= green_time;
                        end else
                            counter <= counter - 1'b1;
                    end
                end

                S_GREEN: begin
                    // 行人请求：立即切换黄灯
                    if (ped_pulse) begin
                        state   <= S_YELLOW;
                        counter <= yellow_time;
                    end else if (tick_1s) begin
                        if (counter <= 8'd1) begin
                            state   <= S_YELLOW;
                            counter <= yellow_time;
                        end else
                            counter <= counter - 1'b1;
                    end
                end

                S_YELLOW: begin
                    if (tick_1s) begin
                        if (counter <= 8'd1) begin
                            state   <= S_RED;
                            counter <= red_time;
                        end else
                            counter <= counter - 1'b1;
                    end
                end

                default: begin
                    state   <= S_RED;
                    counter <= red_time;
                end
            endcase
        end
    end

    // LED 输出映射（高电平有效，顶层统一取反）
    always @(*) begin
        case (state)
            S_RED:    led = 3'b001;  // 红
            S_GREEN:  led = 3'b100;  // 绿
            S_YELLOW: led = 3'b010;  // 黄
            default:  led = 3'b001;
        endcase
    end

endmodule
