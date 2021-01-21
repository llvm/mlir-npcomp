// RUN: npcomp-opt -split-input-file %s | npcomp-opt -canonicalize | FileCheck --dump-input=fail %s

// CHECK-LABEL: func @remove_duplicated
// CHECK-SAME:                    %[[START:.*]]: i64, %[[END:.*]]: i64
func @remove_duplicated(%start: i64, %end: i64) -> !rd.Dataset {
  // CHECK: %[[DS:.*]] = rd.range %[[START]] to %[[END]]
  %0 = rd.range %start to %end by %start : (i64, i64, i64) -> !rd.Dataset
  // CHECK-NOT: rd.range %[[START]] to %[[START]]
  %unused = rd.range %start to %start by %end : (i64, i64, i64) -> !rd.Dataset  // Should be elided.
  // CHECK: return %[[DS]]
  return %0 : !rd.Dataset
}

func @double(%input: i64) -> i64 {
  %0 = addi %input, %input : i64
  return %0 : i64
}

func @less_than_five(%input: i64) -> i1 {
  %five = constant 5 : i64
  %result = cmpi "slt", %input, %five : i64
  return %result : i1
}

// CHECK-LABEL: func @range_map_filter
// CHECK-SAME:                    %[[START:.*]]: i64, %[[END:.*]]: i64
func @range_map_filter(%start: i64, %end: i64) -> !rd.Dataset {
  // CHECK: %[[RANGE:.*]] = rd.range %[[START]] to %[[END]]
  %0 = rd.range %start to %end by %start : (i64, i64, i64) -> !rd.Dataset
  // CHECK: %[[DOUBLED:.*]] = rd.inline_map @double(%[[RANGE]])
  %1 = rd.inline_map @double(%0) : (!rd.Dataset) -> !rd.Dataset
  // CHECK: %[[FILTERED:.*]] = rd.filter %[[DOUBLED]] excluding @less_than_five
  %2 = rd.filter %1 excluding @less_than_five : (!rd.Dataset) -> !rd.Dataset
  // CHECK-NOT: rd.filter
  %3 = rd.filter %1 excluding @less_than_five : (!rd.Dataset) -> !rd.Dataset
  // CHECK-NOT: rd.inline_map
  %4 = rd.inline_map @double(%3) : (!rd.Dataset) -> !rd.Dataset
  // CHECK: return %[[FILTERED]]
  return %2 : !rd.Dataset
}
