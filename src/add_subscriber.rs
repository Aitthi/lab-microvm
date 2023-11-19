use std::sync::{Arc, Mutex};
use event_manager::{SubscriberOps, MutEventSubscriber};
use vmm::EventManager;

use crate::metrics;

pub fn add_subscriber(event_manager: &mut EventManager) -> Arc<Mutex<metrics::PeriodicMetrics>> {
  let firecracker_metrics = Arc::new(Mutex::new(metrics::PeriodicMetrics::new()));
  event_manager.add_subscriber(firecracker_metrics.clone() as Arc<Mutex<(dyn MutEventSubscriber + 'static)>>);
  firecracker_metrics
}