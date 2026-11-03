`timescale 1ns / 1ps
// =============================================================
// 文件: tb_traffic_light.v
// 功能: top_traffic 行为仿真测试平台 (MLK-F3-CZ02-7020 版)
// 说明: 通过参数覆盖加速仿真 —— 1"秒" = 200 个时钟周期(2us@100MHz)，
//       消抖 20ms/50 = 4 周期, 长按判定 200 周期(2us), 连发 100 周期(1us)。
//       覆盖场景: POR -> 正常倒计时 -> 绿灯期行人请求 ->
//                 KEY5 短按切目标 -> KEY5 长按连发+1
// =============================================================
module tb_top_traffic;

    reg clk;
    reg key_ped = 1'b1;   // KEY4, 低电平有效
    reg key_set = 1'b1;   // KEY5, 低电平有效

    wire [6:0] led;       // 低电平点亮

    // 被测设计（参数覆盖加速仿真）
    top_traffic #(
        .CLK_FREQ    (200),      // 200 周期 = 1 "秒" = 2us
        .RED_TIME    (8'd3),
        .YELLOW_TIME (8'd2),
        .GREEN_TIME  (8'd4)
    ) u_dut (
        .clk     (clk),
        .key_ped (key_ped),
        .key_set (key_set),
        .led     (led)
    );

    // 100MHz 时钟
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 按键按下任务（低电平持续 dur 纳秒）
    task automatic press(input integer ns);
    begin
        key_set = 1'b0;
        #(ns);
        key_set = 1'b1;
        #(2000);
    end
    endtask

    // 便于观察的内部信号
    wire [7:0] counter   = u_dut.counter;
    wire [1:0] set_target = u_dut.set_target;
    wire [7:0] red_t     = u_dut.red_time;
    wire [7:0] yel_t     = u_dut.yellow_time;
    wire [7:0] grn_t     = u_dut.green_time;

    initial begin
        // --- POR 后自动运行: 红3 -> 绿4 -> 黄2 -> 红3 ---
        #40000;   // 20 "秒"

        // --- 场景1: 绿灯期(43.3~51.3us, 累计45us处)按 KEY4, 应立即切黄灯 ---
        #5000;
        key_ped = 1'b0;
        #1000;
        key_ped = 1'b1;
        #10000;

        // --- 场景2: KEY5 短按(500ns < 2us 长按阈值) -> 切换配置目标 ---
        press(500);
        // --- 场景3: KEY5 长按(6us >= 2us) -> 连发 +1 ---
        press(6000);
        // --- 场景4: 再短按两次切换目标 ---
        press(500);
        press(500);
        // --- 场景5: 长按一次 ---
        press(6000);

        // --- 观察修改后的循环 ---
        #40000;

        $display("=== Simulation finished ===");
        $stop;
    end

    // 关键信号监测（仅在变化时打印）
    reg [6:0] led_d = 7'h7F;
    reg [7:0] cnt_d = 8'hFF;
    always @(posedge clk) begin
        led_d <= led;
        cnt_d <= counter;
        if (led != led_d || counter != cnt_d)
            $display("t=%0t ns | led=%b | counter=%0d | target=%0d | R=%0d Y=%0d G=%0d",
                     $time, led, counter, set_target, red_t, yel_t, grn_t);
    end

endmodule
