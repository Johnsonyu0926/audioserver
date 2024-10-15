/* cpu_idle.S */
.globl arch_cpu_idle
.globl arch_cpu_atomic_idle
arch_cpu_idle:
    dsb sy
    wfi
    ret
arch_cpu_atomic_idle:
    /* 使用 RK3399 特定的低功耗模式 */
    mrs x0, PMCR_EL0
    orr x0, x0, #(1 << 5)  // 启用深度睡眠模式
    msr PMCR_EL0, x0
    dsb sy
    wfi
    mrs x0, PMCR_EL0
    bic x0, x0, #(1 << 5)  // 禁用深度睡眠模式
    msr PMCR_EL0, x0
    ret
//By GST ARMV8 GCC13.2
