// RUN: tf-opt -xla-legalize-tf %s | FileCheck %s --dump-input-on-failure

//===----------------------------------------------------------------------===//
// BatchNorm op legalizations.
//===----------------------------------------------------------------------===//

// CHECK-LABEL: fusedBatchNorm_notraining
func @fusedBatchNorm_notraining(%arg0: tensor<8x8x8x8xf32>, %arg1: tensor<8xf32>, %arg2: tensor<8xf32>, %arg3: tensor<8xf32>, %arg4: tensor<8xf32>) -> (tensor<8x8x8x8xf32>) {
  // CHECK-NEXT: "xla_hlo.batch_norm_inference"(%arg0, %arg1, %arg2, %arg3, %arg4) {epsilon = 1.000000e-03 : f32, feature_index = 3 : i64} : (tensor<8x8x8x8xf32>, tensor<8xf32>, tensor<8xf32>, tensor<8xf32>, tensor<8xf32>) -> tensor<8x8x8x8xf32>
  %0:5 = "tf.FusedBatchNorm"(%arg0, %arg1, %arg2, %arg3, %arg4) {T = "tfdtype$DT_FLOAT", data_format = "NHWC", epsilon = 0.001 : f32, is_training = false} : (tensor<8x8x8x8xf32>, tensor<8xf32>, tensor<8xf32>, tensor<8xf32>, tensor<8xf32>) -> (tensor<8x8x8x8xf32>, tensor<8xf32>, tensor<8xf32>, tensor<8xf32>, tensor<8xf32>)
  return %0#0 : tensor<8x8x8x8xf32>
}

// CHECK-LABEL: fusedBatchNorm_training
func @fusedBatchNorm_training(%arg0: tensor<8x8x8x8xf32>, %arg1: tensor<8xf32>, %arg2: tensor<8xf32>, %arg3: tensor<8xf32>, %arg4: tensor<8xf32>) -> (tensor<8x8x8x8xf32>) {
  // TODO(riverriddle) Support training.
  // CHECK-NEXT: "tf.FusedBatchNorm"
  %0:5 = "tf.FusedBatchNorm"(%arg0, %arg1, %arg2, %arg3, %arg4) {T = "tfdtype$DT_FLOAT", data_format = "NHWC", epsilon = 0.001 : f32, is_training = true}  : (tensor<8x8x8x8xf32>, tensor<8xf32>, tensor<8xf32>, tensor<8xf32>, tensor<8xf32>) -> (tensor<8x8x8x8xf32>, tensor<8xf32>, tensor<8xf32>, tensor<8xf32>, tensor<8xf32>)
  return %0#0 : tensor<8x8x8x8xf32>
}

//===----------------------------------------------------------------------===//
// Bias op legalizations.
//===----------------------------------------------------------------------===//

// CHECK-LABEL: func @biasAdd_NHWC
func @biasAdd_NHWC(%arg0: tensor<1x32x10x32xi32>, %arg1: tensor<32xi32>) -> tensor<1x32x10x32xi32> {
  // CHECK-NEXT: %0 = "xla_hlo.add"(%arg0, %arg1) {broadcast_dimensions = dense<3> : tensor<1xi64>}
  %0 = "tf.BiasAdd"(%arg0, %arg1) {T = "tfdtype$DT_FLOAT", data_format = "NHWC"} : (tensor<1x32x10x32xi32>, tensor<32xi32>) -> tensor<1x32x10x32xi32>
  return %0 : tensor<1x32x10x32xi32>
}

// CHECK-LABEL: func @biasAdd_NCHW
func @biasAdd_NCHW(%arg0: tensor<1x32x10x32xi32>, %arg1: tensor<32xi32>) -> tensor<1x32x10x32xi32> {
  // CHECK-NEXT: %0 = "xla_hlo.add"(%arg0, %arg1) {broadcast_dimensions = dense<1> : tensor<1xi64>}
  %0 = "tf.BiasAdd"(%arg0, %arg1) {T = "tfdtype$DT_FLOAT", data_format = "NCHW"} : (tensor<1x32x10x32xi32>, tensor<32xi32>) -> tensor<1x32x10x32xi32>
  return %0 : tensor<1x32x10x32xi32>
}

// In the next two tests, the replacement fails because the bias dimension does
// not have the same size as the feature dimension.

// CHECK-LABEL: func @biasAdd_NHWC_invalid
func @biasAdd_NHWC_invalid(%arg0: tensor<1x32x10x2xi32>, %arg1: tensor<32xi32>) -> tensor<1x32x10x2xi32> {
  // CHECK-NOT: xla_hlo.add
  %0 = "tf.BiasAdd"(%arg0, %arg1) {T = "tfdtype$DT_FLOAT", data_format = "NHWC"} : (tensor<1x32x10x2xi32>, tensor<32xi32>) -> tensor<1x32x10x2xi32>
  return %0 : tensor<1x32x10x2xi32>
}

// CHECK-LABEL: func @biasAdd_NCHW_invalid
func @biasAdd_NCHW_invalid(%arg0: tensor<1x10x10x32xi32>, %arg1: tensor<32xi32>) -> tensor<1x10x10x32xi32> {
  // CHECK-NOT: xla_hlo.add
  %0 = "tf.BiasAdd"(%arg0, %arg1) {T = "tfdtype$DT_FLOAT", data_format = "NCHW"} : (tensor<1x10x10x32xi32>, tensor<32xi32>) -> tensor<1x10x10x32xi32>
  return %0 : tensor<1x10x10x32xi32>
}

//===----------------------------------------------------------------------===//
// Binary op legalizations.
//===----------------------------------------------------------------------===//

// CHECK-LABEL: func @add
func @add(%arg0: tensor<2xi32>) -> tensor<2xi32> {
  // CHECK-NEXT:  %[[SUM0:.*]] = xla_hlo.add %arg0, %arg0 : tensor<2xi32>
  // CHECK-NEXT:  %[[SUM1:.*]] = xla_hlo.add %[[SUM0]], %arg0 : tensor<2xi32>
  // CHECK-NEXT:  return %[[SUM1]] : tensor<2xi32>
  %0 = "tf.Add"(%arg0, %arg0) : (tensor<2xi32>, tensor<2xi32>) -> tensor<2xi32>
  %1 = "tf.AddV2"(%0, %arg0) : (tensor<2xi32>, tensor<2xi32>) -> tensor<2xi32>
  return %1: tensor<2xi32>
}

// CHECK-LABEL: func @broadcast_add
func @broadcast_add(%arg0: tensor<1xi32>, %arg1: tensor<1x2xi32>) -> tensor<1x2xi32> {
  // CHECK-NEXT: "xla_hlo.add"(%arg0, %arg1) {broadcast_dimensions = dense<1> : tensor<1xi64>}
  %0 = "tf.Add"(%arg0, %arg1) : (tensor<1xi32>, tensor<1x2xi32>) -> tensor<1x2xi32>
  return %0: tensor<1x2xi32>
}

// CHECK-LABEL: func @broadcast_multi_dim_add
func @broadcast_multi_dim_add(%arg0: tensor<4x1x1xi32>, %arg1: tensor<4x4x4x4xi32>) -> tensor<4x4x4x4xi32> {
  // CHECK-NEXT: "xla_hlo.add"(%arg0, %arg1) {broadcast_dimensions = dense<[1, 2, 3]> : tensor<3xi64>}
  %0 = "tf.Add"(%arg0, %arg1) : (tensor<4x1x1xi32>, tensor<4x4x4x4xi32>) -> tensor<4x4x4x4xi32>
  return %0: tensor<4x4x4x4xi32>
}

// CHECK-LABEL: func @div
func @div(%arg0: tensor<2xi32>) -> tensor<2xi32> {
  // CHECK-NEXT:  %0 = xla_hlo.div %arg0, %arg0 : tensor<2xi32>
  // CHECK-NEXT:  return %0 : tensor<2xi32>
  %0 = "tf.Div"(%arg0, %arg0) : (tensor<2xi32>, tensor<2xi32>) -> tensor<2xi32>
  return %0: tensor<2xi32>
}

// CHECK-LABEL: func @broadcast_div
func @broadcast_div(%arg0: tensor<1xi32>, %arg1: tensor<1x2xi32>) -> tensor<1x2xi32> {
  // CHECK-NEXT: "xla_hlo.div"(%arg0, %arg1) {broadcast_dimensions = dense<1> : tensor<1xi64>}
  %0 = "tf.Div"(%arg0, %arg1) : (tensor<1xi32>, tensor<1x2xi32>) -> tensor<1x2xi32>
  return %0: tensor<1x2xi32>
}

// CHECK-LABEL: func @maximum
func @maximum(%arg0: tensor<4xf32>, %arg1: tensor<4xf32>) -> tensor<4xf32> {
  // CHECK:  xla_hlo.max %arg0, %arg1 : tensor<4xf32>
  %0 = "tf.Maximum"(%arg0, %arg1) : (tensor<4xf32>, tensor<4xf32>) -> tensor<4xf32>
  return %0 : tensor<4xf32>
}

// CHECK-LABEL: func @minimum
func @minimum(%arg0: tensor<4xf32>, %arg1: tensor<4xf32>) -> tensor<4xf32> {
  // CHECK:  xla_hlo.min %arg0, %arg1 : tensor<4xf32>
  %0 = "tf.Minimum"(%arg0, %arg1) : (tensor<4xf32>, tensor<4xf32>) -> tensor<4xf32>
  return %0 : tensor<4xf32>
}

// CHECK-LABEL: func @mul
func @mul(%arg0: tensor<2xi32>) -> tensor<2xi32> {
  // CHECK-NEXT:  %0 = xla_hlo.mul %arg0, %arg0 : tensor<2xi32>
  // CHECK-NEXT:  return %0 : tensor<2xi32>
  %0 = "tf.Mul"(%arg0, %arg0) : (tensor<2xi32>, tensor<2xi32>) -> tensor<2xi32>
  return %0: tensor<2xi32>
}

// CHECK-LABEL: func @broadcast_mul
func @broadcast_mul(%arg0: tensor<1xi32>, %arg1: tensor<1x2xi32>) -> tensor<1x2xi32> {
  // CHECK-NEXT: "xla_hlo.mul"(%arg0, %arg1) {broadcast_dimensions = dense<1> : tensor<1xi64>}
  %0 = "tf.Mul"(%arg0, %arg1) : (tensor<1xi32>, tensor<1x2xi32>) -> tensor<1x2xi32>
  return %0: tensor<1x2xi32>
}

// CHECK-LABEL: func @real_div
func @real_div(%arg0: tensor<2xi32>) -> tensor<2xi32> {
  // CHECK-NEXT:  %0 = xla_hlo.div %arg0, %arg0 : tensor<2xi32>
  %0 = "tf.RealDiv"(%arg0, %arg0) : (tensor<2xi32>, tensor<2xi32>) -> tensor<2xi32>
  return %0: tensor<2xi32>
}

// CHECK-LABEL: func @broadcast_real_div
func @broadcast_real_div(%arg0: tensor<1xi32>, %arg1: tensor<1x2xi32>) -> tensor<1x2xi32> {
  // CHECK-NEXT: "xla_hlo.div"(%arg0, %arg1) {broadcast_dimensions = dense<1> : tensor<1xi64>}
  %0 = "tf.RealDiv"(%arg0, %arg1) : (tensor<1xi32>, tensor<1x2xi32>) -> tensor<1x2xi32>
  return %0: tensor<1x2xi32>
}

// CHECK-LABEL: func @sub
func @sub(%arg0: tensor<2xi32>) -> tensor<2xi32> {
  // CHECK-NEXT:  %0 = xla_hlo.sub %arg0, %arg0 : tensor<2xi32>
  // CHECK-NEXT:  return %0 : tensor<2xi32>
  %0 = "tf.Sub"(%arg0, %arg0) : (tensor<2xi32>, tensor<2xi32>) -> tensor<2xi32>
  return %0: tensor<2xi32>
}

// CHECK-LABEL: func @broadcast_sub
func @broadcast_sub(%arg0: tensor<1xi32>, %arg1: tensor<1x2xi32>) -> tensor<1x2xi32> {
  // CHECK-NEXT: "xla_hlo.sub"(%arg0, %arg1) {broadcast_dimensions = dense<1> : tensor<1xi64>}
  %0 = "tf.Sub"(%arg0, %arg1) : (tensor<1xi32>, tensor<1x2xi32>) -> tensor<1x2xi32>
  return %0: tensor<1x2xi32>
}


//===----------------------------------------------------------------------===//
// Compare op legalizations.
//===----------------------------------------------------------------------===//

// CHECK-LABEL: func @greater
func @greater(%arg0: tensor<2xi32>) -> tensor<2xi1> {
  // CHECK-NEXT:  "xla_hlo.compare"(%arg0, %arg0) {comparison_direction = "GT"}
  %0 = "tf.Greater"(%arg0, %arg0) : (tensor<2xi32>, tensor<2xi32>) -> tensor<2xi1>
  return %0: tensor<2xi1>
}

// CHECK-LABEL: func @broadcast_greater
func @broadcast_greater(%arg0: tensor<1xi32>, %arg1: tensor<1x2xi32>) -> tensor<1x2xi1> {
  // CHECK-NEXT: "xla_hlo.compare"(%arg0, %arg1) {broadcast_dimensions = dense<1> : tensor<1xi64>, comparison_direction = "GT"}
  %0 = "tf.Greater"(%arg0, %arg1) : (tensor<1xi32>, tensor<1x2xi32>) -> tensor<1x2xi1>
  return %0: tensor<1x2xi1>
}

// CHECK-LABEL: func @greater_equal
func @greater_equal(%arg0: tensor<2xi32>) -> tensor<2xi1> {
  // CHECK-NEXT:  "xla_hlo.compare"(%arg0, %arg0) {comparison_direction = "GE"}
  %0 = "tf.GreaterEqual"(%arg0, %arg0) : (tensor<2xi32>, tensor<2xi32>) -> tensor<2xi1>
  return %0: tensor<2xi1>
}

// CHECK-LABEL: func @broadcast_greater_equal
func @broadcast_greater_equal(%arg0: tensor<1xi32>, %arg1: tensor<1x2xi32>) -> tensor<1x2xi1> {
  // CHECK-NEXT: "xla_hlo.compare"(%arg0, %arg1) {broadcast_dimensions = dense<1> : tensor<1xi64>, comparison_direction = "GE"}
  %0 = "tf.GreaterEqual"(%arg0, %arg1) : (tensor<1xi32>, tensor<1x2xi32>) -> tensor<1x2xi1>
  return %0: tensor<1x2xi1>
}

// CHECK-LABEL: func @less
func @less(%arg0: tensor<2xi32>) -> tensor<2xi1> {
  // CHECK-NEXT:  "xla_hlo.compare"(%arg0, %arg0) {comparison_direction = "LT"}
  %0 = "tf.Less"(%arg0, %arg0) : (tensor<2xi32>, tensor<2xi32>) -> tensor<2xi1>
  return %0: tensor<2xi1>
}

// CHECK-LABEL: func @broadcast_less
func @broadcast_less(%arg0: tensor<1xi32>, %arg1: tensor<1x2xi32>) -> tensor<1x2xi1> {
  // CHECK-NEXT: "xla_hlo.compare"(%arg0, %arg1) {broadcast_dimensions = dense<1> : tensor<1xi64>, comparison_direction = "LT"}
  %0 = "tf.Less"(%arg0, %arg1) : (tensor<1xi32>, tensor<1x2xi32>) -> tensor<1x2xi1>
  return %0: tensor<1x2xi1>
}

// CHECK-LABEL: func @less_equal
func @less_equal(%arg0: tensor<2xi32>) -> tensor<2xi1> {
  // CHECK-NEXT:  "xla_hlo.compare"(%arg0, %arg0) {comparison_direction = "LE"}
  %0 = "tf.LessEqual"(%arg0, %arg0) : (tensor<2xi32>, tensor<2xi32>) -> tensor<2xi1>
  return %0: tensor<2xi1>
}

// CHECK-LABEL: func @broadcast_less_equal
func @broadcast_less_equal(%arg0: tensor<1xi32>, %arg1: tensor<1x2xi32>) -> tensor<1x2xi1> {
  // CHECK-NEXT: "xla_hlo.compare"(%arg0, %arg1) {broadcast_dimensions = dense<1> : tensor<1xi64>, comparison_direction = "LE"}
  %0 = "tf.LessEqual"(%arg0, %arg1) : (tensor<1xi32>, tensor<1x2xi32>) -> tensor<1x2xi1>
  return %0: tensor<1x2xi1>
}

//===----------------------------------------------------------------------===//
// Concat op legalizations.
//===----------------------------------------------------------------------===//

// CHECK-LABEL: func @concat_v2
func @concat_v2(%arg0: tensor<3x3xf32>, %arg1: tensor<3x3xf32>) -> tensor<6x3xf32> {
  // CHECK: "xla_hlo.concatenate"({{.*}}) {dimension = 0 : i64} : (tensor<3x3xf32>, tensor<3x3xf32>) -> tensor<6x3xf32>
  %axis = "tf.Const"() { value = dense<0> : tensor<i64> } : () -> tensor<i64>
  %1 = "tf.ConcatV2"(%arg0, %arg1, %axis) {N = 2 : i64} : (tensor<3x3xf32>, tensor<3x3xf32>, tensor<i64>) -> tensor<6x3xf32>
  return %1 : tensor<6x3xf32>
}

// CHECK-LABEL: func @concat_v2_neg_axis
func @concat_v2_neg_axis(%arg0: tensor<3x3xf32>, %arg1: tensor<3x3xf32>) -> tensor<6x3xf32> {
  // CHECK: "xla_hlo.concatenate"({{.*}}) {dimension = 0 : i64} : (tensor<3x3xf32>, tensor<3x3xf32>) -> tensor<6x3xf32>

  %axis = "tf.Const"() { value = dense<-2> : tensor<i64> } : () -> tensor<i64>
  %1 = "tf.ConcatV2"(%arg0, %arg1, %axis) {N = 2 : i64} : (tensor<3x3xf32>, tensor<3x3xf32>, tensor<i64>) -> tensor<6x3xf32>
  return %1 : tensor<6x3xf32>
}

// CHECK-LABEL: func @concat_v2_1d_axis
func @concat_v2_1d_axis(%arg0: tensor<3x3xf32>, %arg1: tensor<3x3xf32>) -> tensor<3x6xf32> {
  // CHECK: "xla_hlo.concatenate"({{.*}}) {dimension = 1 : i64} : (tensor<3x3xf32>, tensor<3x3xf32>) -> tensor<3x6xf32>

  %axis = "tf.Const"() { value = dense<[1]> : tensor<1xi64> } : () -> tensor<1xi64>
  %1 = "tf.ConcatV2"(%arg0, %arg1, %axis) {N = 2 : i64} : (tensor<3x3xf32>, tensor<3x3xf32>, tensor<1xi64>) -> tensor<3x6xf32>
  return %1 : tensor<3x6xf32>
}

// CHECK-LABEL: func @concat_v2_non_const_axis
func @concat_v2_non_const_axis(%arg0: tensor<3x3xf32>, %arg1: tensor<3x3xf32>, %axis: tensor<i64>) -> tensor<3x6xf32> {
  // CHECK: "tf.ConcatV2"

  %1 = "tf.ConcatV2"(%arg0, %arg1, %axis) {N = 2 : i64} : (tensor<3x3xf32>, tensor<3x3xf32>, tensor<i64>) -> tensor<3x6xf32>
  return %1 : tensor<3x6xf32>
}

// CHECK-LABEL: func @concat_v2_unranked
func @concat_v2_unranked(%arg0: tensor<*xf32>, %arg1: tensor<*xf32>) -> tensor<*xf32> {
  // CHECK: "tf.ConcatV2"

  %axis = "tf.Const"() { value = dense<0> : tensor<i64> } : () -> tensor<i64>
  %1 = "tf.ConcatV2"(%arg0, %arg1, %axis) {N = 2 : i64} : (tensor<*xf32>, tensor<*xf32>, tensor<i64>) -> tensor<*xf32>
  return %1 : tensor<*xf32>
}

//===----------------------------------------------------------------------===//
// Identity op legalizations.
//===----------------------------------------------------------------------===//

// CHECK-LABEL: func @identity
func @identity(%arg0: tensor<1xi32>) -> tensor<1xi32> {
  // CHECK-NEXT:  return %arg0 : tensor<1xi32>
  %0 = "tf.Identity"(%arg0) : (tensor<1xi32>) -> tensor<1xi32>
  return %0: tensor<1xi32>
}

//===----------------------------------------------------------------------===//
// Nullary op legalizations.
//===----------------------------------------------------------------------===//

// CHECK-LABEL: @const
func @const() -> tensor<2xi32> {
  // CHECK-NEXT: "xla_hlo.constant"() {value = dense<0> : tensor<2xi32>}
  %0 = "tf.Const"() {device = "", name = "", dtype = "tfdtype$DT_INT32", value = dense<0> : tensor<2xi32>} : () -> (tensor<2xi32>)
  return %0: tensor<2xi32>
}

//===----------------------------------------------------------------------===//
// Matmul op legalizations.
//===----------------------------------------------------------------------===//

// CHECK-LABEL: matmul_notranspose
func @matmul_notranspose(%arg0: tensor<5x7xf32>, %arg1: tensor<7x11xf32>) -> tensor<5x11xf32> {
  // CHECK: "xla_hlo.dot"(%arg0, %arg1)
  %0 = "tf.MatMul"(%arg0, %arg1) {transpose_a = false, transpose_b = false} : (tensor<5x7xf32>, tensor<7x11xf32>) -> tensor<5x11xf32>

  return %0 : tensor<5x11xf32>
}

//===----------------------------------------------------------------------===//
// MaxPool op legalizations.
//===----------------------------------------------------------------------===//

// CHECK-LABEL: maxpool_valid_padding
// CHECK-SAME: %[[ARG:.*]]: tensor
func @maxpool_valid_padding(%arg0: tensor<2x12x20x7xi32>) -> tensor<2x3x5x7xi32> {
  // CHECK: %[[INIT:.*]] = "xla_hlo.constant"() {value = dense<-2147483648> : tensor<i32>}
  // CHECK: "xla_hlo.reduce_window"(%[[ARG]], %[[INIT]])
  // CHECK: xla_hlo.max
  // CHECK: xla_hlo.return
  // CHECK: {window_dimensions = dense<[1, 2, 2, 1]> : tensor<4xi64>, window_strides = dense<[1, 4, 4, 1]> : tensor<4xi64>}

  %0 = "tf.MaxPool"(%arg0) {data_format = "NHWC", ksize = [1, 2, 2, 1], padding = "VALID", strides = [1, 4, 4, 1]} : (tensor<2x12x20x7xi32>) -> tensor<2x3x5x7xi32>
  return %0 : tensor<2x3x5x7xi32>
}

//===----------------------------------------------------------------------===//
// Pack op legalizations.
//===----------------------------------------------------------------------===//

// CHECK-LABEL: func @pack
func @pack(%arg0: tensor<2xi32>, %arg1: tensor<2xi32>) -> tensor<2x2xi32> {
  // CHECK: "xla_hlo.reshape"({{.*}}) : (tensor<2xi32>) -> tensor<1x2xi32>
  // CHECK: "xla_hlo.reshape"({{.*}}) : (tensor<2xi32>) -> tensor<1x2xi32>
  // CHECK: "xla_hlo.concatenate"({{.*}}) {dimension = 0 : i64} : (tensor<1x2xi32>, tensor<1x2xi32>) -> tensor<2x2xi32>

  %0 = "tf.Pack"(%arg0, %arg1) {N = 2 : i64} : (tensor<2xi32>, tensor<2xi32>) -> tensor<2x2xi32>
  return %0 : tensor<2x2xi32>
}

//===----------------------------------------------------------------------===//
// Relu op legalizations.
//===----------------------------------------------------------------------===//

// CHECK-LABEL: func @relu
func @relu(%arg0: tensor<1xi32>) -> tensor<1xi32> {
  // CHECK-NEXT: %[[ZERO:.*]] = "xla_hlo.constant"() {value = dense<0> : tensor<1xi32>}
  // CHECK-NEXT: xla_hlo.max %[[ZERO]], %arg0 : tensor<1xi32>
  %0 = "tf.Relu"(%arg0) : (tensor<1xi32>) -> tensor<1xi32>
  return %0: tensor<1xi32>
}

// CHECK-LABEL: func @relu6
func @relu6(%arg0: tensor<1xi32>) -> tensor<1xi32> {
  // CHECK-NEXT: %[[ZERO:.*]] = "xla_hlo.constant"() {value = dense<0> : tensor<1xi32>}
  // CHECK-NEXT: %[[SIX:.*]] = "xla_hlo.constant"() {value = dense<6> : tensor<1xi32>}
  // CHECK-NEXT: "xla_hlo.clamp"(%[[ZERO]], %arg0, %[[SIX]]) : (tensor<1xi32>, tensor<1xi32>, tensor<1xi32>) -> tensor<1xi32>
  %0 = "tf.Relu6"(%arg0) : (tensor<1xi32>) -> tensor<1xi32>
  return %0: tensor<1xi32>
}

//===----------------------------------------------------------------------===//
// Select op legalizations.
//===----------------------------------------------------------------------===//

// CHECK-LABEL: func @select
func @select(%arg0: tensor<2xi1>, %arg1: tensor<2xi32>, %arg2: tensor<2xi32>) -> tensor<2xi32> {
  // CHECK-NEXT: "xla_hlo.select"(%arg0, %arg1, %arg2)
  %0 = "tf.Select"(%arg0, %arg1, %arg2) : (tensor<2xi1>, tensor<2xi32>, tensor<2xi32>) -> tensor<2xi32>
  return %0: tensor<2xi32>
}

// CHECK-LABEL: func @select_float
func @select_float(%arg0: tensor<2xi1>, %arg1: tensor<2xf32>, %arg2: tensor<2xf32>) -> tensor<2xf32> {
  // CHECK-NEXT: "xla_hlo.select"(%arg0, %arg1, %arg2)
  %0 = "tf.Select"(%arg0, %arg1, %arg2) : (tensor<2xi1>, tensor<2xf32>, tensor<2xf32>) -> tensor<2xf32>
  return %0: tensor<2xf32>
}

// CHECK-LABEL: func @select_multidimensional
func @select_multidimensional(%arg0: tensor<3x2xi1>, %arg1: tensor<3x2xi32>, %arg2: tensor<3x2xi32>) -> tensor<3x2xi32> {
  // CHECK-NEXT: "xla_hlo.select"(%arg0, %arg1, %arg2)
  %0 = "tf.Select"(%arg0, %arg1, %arg2) : (tensor<3x2xi1>, tensor<3x2xi32>, tensor<3x2xi32>) -> tensor<3x2xi32>
  return %0: tensor<3x2xi32>
}

//===----------------------------------------------------------------------===//
// Softmax op legalizations.
//===----------------------------------------------------------------------===//

// CHECK-LABEL: func @simple_softmax
// CHECK-SAME: (%[[ARG0:.*]]: tensor<2x3xf32>)
func @simple_softmax(%arg0: tensor<2x3xf32>) -> tensor<2x3xf32> {

  // Verify reduce op for max computation and its body.
  // CHECK: %[[NEG_INF:.*]] = "xla_hlo.constant"() {value = dense<0xFF800000> : tensor<f32>}
  // CHECK: %[[MAX:.*]] = "xla_hlo.reduce"(%[[ARG0]], %[[NEG_INF]])
  // CHECK:  xla_hlo.max
  // CHECK: "xla_hlo.return"
  // CHECK: {dimensions = dense<1> : tensor<1xi64>} : (tensor<2x3xf32>, tensor<f32>) -> tensor<2xf32>

  // CHECK: %[[SHIFTED_INP:.*]] = "xla_hlo.sub"(%[[ARG0]], %[[MAX]]) {broadcast_dimensions = dense<0> : tensor<1xi64>}
  // CHECK: %[[EXP:.*]] = "xla_hlo.exp"(%[[SHIFTED_INP]])
  // CHECK: %[[CASTED_EXP:.*]] = "xla_hlo.convert"(%[[EXP]]) : (tensor<2x3xf32>) -> tensor<2x3xf32>

  // Verify reduce op for summation and its body.
  // CHECK: %[[ZERO:.*]] = "xla_hlo.constant"() {value = dense<0.000000e+00> : tensor<f32>}
  // CHECK: %[[SUM:.*]] = "xla_hlo.reduce"(%[[CASTED_EXP]], %[[ZERO]])
  // CHECK:  xla_hlo.add
  // CHECK: "xla_hlo.return"
  // CHECK: {dimensions = dense<1> : tensor<1xi64>}
  // CHECK: %[[CASTED_SUM:.*]] = "xla_hlo.convert"(%[[SUM]]) : (tensor<2xf32>) -> tensor<2xf32>

  // CHECK: %[[RESULT:.*]] = "xla_hlo.div"(%[[EXP]], %[[CASTED_SUM]]) {broadcast_dimensions = dense<0> : tensor<1xi64>}
  // return %[[RESULT]]

  %0 = "tf.Softmax"(%arg0) : (tensor<2x3xf32>) -> tensor<2x3xf32>
  return %0: tensor<2x3xf32>
}

// CHECK-LABEL: bf16_softmax
func @bf16_softmax(%arg0: tensor<2x3xbf16>) -> tensor<2x3xbf16> {
  // Verify that conversion to f32 and then back to bf16 are introduced.

  // CHECK: "xla_hlo.convert"({{.*}}) : (tensor<2x3xbf16>) -> tensor<2x3xf32>
  // CHECK: "xla_hlo.convert"({{.*}}) : (tensor<2xf32>) -> tensor<2xbf16>

  %0 = "tf.Softmax"(%arg0) : (tensor<2x3xbf16>) -> tensor<2x3xbf16>
  return %0: tensor<2x3xbf16>
}

// CHECK-LABEL: rank4_softmax
func @rank4_softmax(%arg0: tensor<2x3x4x5xf16>) -> tensor<2x3x4x5xf16> {
  // Verify that reduce op dimensions and broadcast dimensions are correct.

  // CHECK: "xla_hlo.reduce"
  // CHECK: dimensions = dense<3>

  // CHECK: "xla_hlo.reduce"
  // CHECK: dimensions = dense<3>

  // CHECK: "xla_hlo.div"{{.*}} {broadcast_dimensions = dense<[0, 1, 2]> : tensor<3xi64>}
  %0 = "tf.Softmax"(%arg0) : (tensor<2x3x4x5xf16>) -> tensor<2x3x4x5xf16>
  return %0: tensor<2x3x4x5xf16>
}

//===----------------------------------------------------------------------===//
// Unary op legalizations.
//===----------------------------------------------------------------------===//

// CHECK-LABEL: reshape
func @reshape(%arg0: tensor<2xf32>, %arg1: tensor<2xi32>) -> tensor<1x1xf32> {
  // CHECK:  %0 = "xla_hlo.reshape"(%arg0) : (tensor<2xf32>) -> tensor<1x1xf32>
  %0 = "tf.Reshape"(%arg0, %arg1) : (tensor<2xf32>, tensor<2xi32>) -> tensor<1x1xf32>
  return %0 : tensor<1x1xf32>
}

// CHECK-LABEL: reshape_dynamic
func @reshape_dynamic(%arg0: tensor<*xf32>, %arg1: tensor<2xi32>) -> tensor<?x?xf32> {
  // CHECK:  %0 = "tf.Reshape"(%arg0, %arg1) : (tensor<*xf32>, tensor<2xi32>) -> tensor<?x?xf32>
  %0 = "tf.Reshape"(%arg0, %arg1) : (tensor<*xf32>, tensor<2xi32>) -> tensor<?x?xf32>
  return %0 : tensor<?x?xf32>
}

// CHECK-LABEL: squeeze
func @squeeze(%arg0: tensor<1x1x10xf32>) -> tensor<1x10xf32> {
  // CHECK-NEXT: %0 = "xla_hlo.reshape"(%arg0) : (tensor<1x1x10xf32>) -> tensor<1x10xf32>
  %0 = "tf.Squeeze"(%arg0) : (tensor<1x1x10xf32>) -> tensor<1x10xf32>
  return %0 : tensor<1x10xf32>
}

// CHECK-LABEL: squeeze_dynamic
func @squeeze_dynamic(%arg0: tensor<?x10xf32>) -> tensor<*xf32> {
  // CHECK-NEXT: %0 = "tf.Squeeze"(%arg0) : (tensor<?x10xf32>) -> tensor<*xf32>
  %0 = "tf.Squeeze"(%arg0) : (tensor<?x10xf32>) -> tensor<*xf32>
  return %0 : tensor<*xf32>
}

// CHECK-LABEL: expand_dims
func @expand_dims(%arg0: tensor<2xf32>, %axis: tensor<i32>) -> tensor<1x2xf32> {
  // CHECK: "xla_hlo.reshape"{{.*}} : (tensor<2xf32>) -> tensor<1x2xf32>
  %0 = "tf.ExpandDims"(%arg0, %axis) : (tensor<2xf32>, tensor<i32>) -> tensor<1x2xf32>
  return %0 : tensor<1x2xf32>
}
