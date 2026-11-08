// vdot timing harness
// 直接驱动 VIMacU 的 vdot 操作类型，用于单元级时序分析。
// 这不是完整香山顶层，也不包含译码器。
module vdot_timing_top(
  input  logic         clock,
  input  logic         reset,
  input  logic [127:0] vs1,
  input  logic [127:0] vs2,
  output logic [31:0]  dot,
  output logic         valid
);

  // 输入寄存器：把外部输入先打一拍，隔离输入侧组合逻辑。
  logic [127:0] vs1_q;
  logic [127:0] vs2_q;
  logic         in_valid_q;

  always_ff @(posedge clock) begin
    if (reset) begin
      vs1_q      <= '0;
      vs2_q      <= '0;
      in_valid_q <= 1'b0;
    end else begin
      vs1_q      <= vs1;
      vs2_q      <= vs2;
      in_valid_q <= 1'b1;
    end
  end

  logic [127:0] result;
  logic         out_valid;

  VIMacU u_vimac (
    .clock(clock),
    .reset(reset),

    .io_in_ready(),                 // 本测试不反压
    .io_in_valid(in_valid_q),

    // 输入级控制：VimacType.vdot = 9'h067
    .io_in_bits_ctrl_fuOpType(9'h067),
    .io_in_bits_ctrl_vpu_vsew(2'b00),   // e8
    .io_in_bits_ctrl_vpu_vuopIdx(7'd0),

    // 输出级控制：与输入级保持一致
    .io_in_bits_ctrlPipe_2_fuOpType(9'h067),
    .io_in_bits_ctrlPipe_2_robIdx_flag(1'b0),
    .io_in_bits_ctrlPipe_2_robIdx_value(8'd0),
    .io_in_bits_ctrlPipe_2_pdest(8'd0),
    .io_in_bits_ctrlPipe_2_vecWen(1'b1),
    .io_in_bits_ctrlPipe_2_v0Wen(1'b1),
    .io_in_bits_ctrlPipe_2_vpu_vill(1'b0),
    .io_in_bits_ctrlPipe_2_vpu_vma(1'b0),
    .io_in_bits_ctrlPipe_2_vpu_vta(1'b0),
    .io_in_bits_ctrlPipe_2_vpu_vsew(2'b00), // e8
    .io_in_bits_ctrlPipe_2_vpu_vlmul(3'b000), // m1
    .io_in_bits_ctrlPipe_2_vpu_vm(1'b1),      // 无掩码
    .io_in_bits_ctrlPipe_2_vpu_vstart(8'd0),
    .io_in_bits_ctrlPipe_2_vpu_vuopIdx(7'd0),
    .io_in_bits_validPipe_2(1'b1),

    // 数据：src_0 = vs1, src_1 = vs2, src_2 = 旧 vd
    .io_in_bits_data_src_0(vs1_q),
    .io_in_bits_data_src_1(vs2_q),
    .io_in_bits_data_src_2('0),
    .io_in_bits_dataPipe_2_src_2('0),
    .io_in_bits_dataPipe_2_src_3('0),
    .io_in_bits_dataPipe_2_src_4(8'd8),

    // 性能调试端口全部置零
    .io_in_bits_perfDebugInfo_eliminatedMove(1'b0),
    .io_in_bits_perfDebugInfo_renameTime(64'd0),
    .io_in_bits_perfDebugInfo_dispatchTime(64'd0),
    .io_in_bits_perfDebugInfo_enqRsTime(64'd0),
    .io_in_bits_perfDebugInfo_selectTime(64'd0),
    .io_in_bits_perfDebugInfo_issueTime(64'd0),
    .io_in_bits_perfDebugInfo_writebackTime(64'd0),
    .io_in_bits_perfDebugInfo_runahead_checkpoint_id(64'd0),
    .io_in_bits_perfDebugInfo_tlbFirstReqTime(64'd0),
    .io_in_bits_perfDebugInfo_tlbRespTime(64'd0),

    .io_out_ready(1'b1),
    .io_out_valid(out_valid),
    .io_out_bits_res_data(result),

    .io_vxrm(2'd0)
  );

  // 输出寄存器：把结果再打一拍，便于报告寄存器到寄存器路径。
  always_ff @(posedge clock) begin
    if (reset) begin
      dot   <= '0;
      valid <= 1'b0;
    end else begin
      valid <= out_valid;
      if (out_valid) begin
        dot <= result[31:0];
      end
    end
  end

endmodule

