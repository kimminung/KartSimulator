import Foundation

/// 현재 프로세스의 물리 메모리 사용량(MB, `phys_footprint` — Xcode 메모리 게이지와 같은 기준). PERF 로그에 붙여 Instruments 없이도
/// 실기기·시뮬레이터에서 메모리 예산을 읽는다(결정 61, Issue #45·#46).
enum MemoryFootprint {
    static func currentMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1_048_576
    }
}
