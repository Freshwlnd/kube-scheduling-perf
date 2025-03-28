# kube-scheduling-perf

## Collecting Scheduling Metrics

This project uses the [kube-apiserver-audit-exporter](https://github.com/wzshiming/kube-apiserver-audit-exporter) to collect metrics from the kube-apiserver's audit log, providing a unified view of scheduling performance across different scheduler implementations.

## Supported Scheduler Implementations

The test framework enables both individual scheduler evaluation and comparative analysis across implementations, capturing detailed performance metrics under various workload scenarios.

The benchmark framework supports comprehensive performance testing of these Kubernetes schedulers:

- Kueue
- Volcano
- YuniKorn

## Getting Started

## Prerequisites and Setup

> This project allows for quick deletion and recreation of the cluster, as it uses the kind local registry.  
> This approach also helps control variables during different scheduler tests and does not have to wait for the slow deletion process.  

### Dependencies

To use this project, you'll need to have the following tools installed:

- docker
- kubectl

### Running Tests

For comprehensive performance comparison:

``` bash
make
```

The command sequentially runs performance tests for each supported scheduler and compiles the results into a final report in `./results/`.

### Debug

Running scheduler tests in parallel with real-time monitoring allows viewing intermediate results without waiting for all tests to complete, though data may be incomplete until final reports are generated.

To create a cluster, run the following command:

``` bash
make up NODES_SIZE=1000 QUEUES_SIZE=1 JOBS_SIZE_PER_QUEUE=500 PODS_SIZE_PER_JOB=20 GANG=false
```

Minimum hardware:
- 16 CPU cores
- 16 GB RAM

Once the cluster is up, you can access the performance dashboard at:

`http://127.0.0.1:8080/grafana/d/perf/`

To delete the cluster:

``` bash
make down
```

## Troubleshooting

### "Too Many Open Files" Error in Linux

If you encounter "Too many open files" error in Linux environment, run the following commands to increase the file watch limits:

``` bash
echo fs.inotify.max_user_watches=655360 | sudo tee -a /etc/sysctl.conf
echo fs.inotify.max_user_instances=1280 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```
