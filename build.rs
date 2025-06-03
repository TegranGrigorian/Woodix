fn main() {
    // Tell Cargo to rerun this script if the linker script changes
    println!("cargo:rerun-if-changed=linker.ld");
    
    // Note: We're not adding linker args here as they're in .cargo/config.toml
}
