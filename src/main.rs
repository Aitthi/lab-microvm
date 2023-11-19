mod metrics;
mod add_subscriber;
use std::sync::Arc;
use seccompiler::BpfThreadMap;
use vmm::{vmm_config::instance_info::{InstanceInfo, VmState}, resources::VmResources, logger::info, FcExitCode, EventManager};

/// Default byte limit of accepted http requests on API and MMDS servers.
pub const HTTP_MAX_PAYLOAD_SIZE: usize = 51200;

fn main() {
    // println!("Hello, world!");

    let instance_info = InstanceInfo {
        app_name: "Firecracker".to_string(),
        id: "vm-001".into(),
        state: VmState::NotStarted,
        vmm_version: "1.6.0-dev".into(),
    };
    let mut seccomp_filters = BpfThreadMap::new();
    seccomp_filters.insert("vmm".to_string(), Arc::new(vec![]));
    // seccomp_filters.insert("api".to_string(), Arc::new(vec![]));
    seccomp_filters.insert("vcpu".to_string(), Arc::new(vec![]));

    let boot_timer_enabled = false;
    let mmds_size_limit = HTTP_MAX_PAYLOAD_SIZE;
    let mut event_manager = EventManager::new().unwrap();
    let firecracker_metrics = add_subscriber::add_subscriber(&mut event_manager);

    println!("instance_info: {:#?}", instance_info);

    // read dev-vm.json
    let config_json = std::fs::read_to_string("config/dev-vm.json").unwrap();
    // println!("config_json: {:#?}", config_json);
    let mut vm_resources = VmResources::from_json(&config_json, &instance_info, mmds_size_limit, None).unwrap();
    vm_resources.boot_timer = boot_timer_enabled;
    // println!("vm_resources: {:#?}", vm_resources);

    let r_vmm = match vmm::builder::build_and_boot_microvm(
        &instance_info,
        &vm_resources,
        &mut event_manager,
        &seccomp_filters,
    ) {
        Ok(vmm) => vmm,
        Err(e) => {
            println!("Failed to build microvm: {:?}", e);
            std::process::exit(0);
        }   
    };

    // let r_vmma = r_vmm.clone();
    // std::thread::spawn(move || {
        // 10s shutdown
        // thread::sleep(Duration::from_secs(10));
        // println!("\nsleep 10s, then pause_vm and stop");
        // let mut vmm = r_vmma.lock().unwrap();
        // vmm.pause_vm().expect("pause_vm failed");
        // println!("\npause_vm success");
        // vmm.stop(FcExitCode::Ok);
        // std::process::exit(0);
    // });
    
    info!("Successfully started microvm that was configured from one single json");
    firecracker_metrics
        .lock()
        .expect("Poisoned lock")
        .start(metrics::WRITE_METRICS_PERIOD_MS);

    // Run the EventManager that drives everything in the microVM.
    loop {
        event_manager
            .run()
            .expect("Failed to start the event manager");

        // println!("r_vmm id: {:#?}", r_vmm.lock().unwrap());
        match r_vmm.lock().unwrap().shutdown_exit_code() {
            Some(FcExitCode::Ok) => break,
            Some(exit_code) =>{
                // return Err(RunWithoutApiError::Shutdown(exit_code)
                println!("exit_code: {:?}", exit_code);
                break;
            },
            None => continue,
        }
    }
}
