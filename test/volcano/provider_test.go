package volcano_test

import (
	"context"
	_ "embed"
	"fmt"
	"strings"
	"time"

	"github.com/wzshiming/kube-scheduling-perf/test/utils"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/types"
	"sigs.k8s.io/e2e-framework/klient/decoder"
	"sigs.k8s.io/e2e-framework/klient/k8s"
)

//go:embed init.yaml
var initYaml string

//go:embed init_queue.yaml
var initQueueYaml string

//go:embed batch_job.yaml
var batchJobYaml string

type VolcanoProvider struct {
	utils.Options
}

func (p *VolcanoProvider) AddNodes(ctx context.Context) error {
	builder := utils.NewNodeBuilder().
		WithFastReady().
		WithCPU(p.CpuPerNode).
		WithMemory(p.MemoryPerNode)
	for i := range p.NodeSize {
		err := utils.Resources.Create(ctx,
			builder.
				WithName(fmt.Sprintf("node-%d", i)).
				Build(),
		)
		if err != nil {
			return err
		}
	}
	return nil
}

func (p *VolcanoProvider) InitCase(ctx context.Context) error {
	cpuPerQueue, err := resource.ParseQuantity(p.CpuPerQueue)
	if err != nil {
		return err
	}

	memoryPerQueue, err := resource.ParseQuantity(p.MemoryPerQueue)
	if err != nil {
		return err
	}

	var hierarchy bool

	cpuCapabilityTotal := ""
	cpuCapability := ""
	cpuDeserved := ""
	cpuGuarantee := ""

	if p.CpuLendingLimit != "" {
		cpuLendingLimit, err := resource.ParseQuantity(p.CpuLendingLimit)
		if err != nil {
			return err
		}

		hierarchy = true
		cpuCapabilityTotal = utils.TimesQuantity(cpuPerQueue, p.QueueSize+p.ImpactingQueuesSize+p.CriticalQueuesSize).String()
		cpuCapability = cpuPerQueue.String()
		cpuPerQueue.Sub(cpuLendingLimit)
		cpuDeserved = cpuPerQueue.String()
	} else {
		cpuCapabilityTotal = utils.TimesQuantity(cpuPerQueue, p.QueueSize+p.ImpactingQueuesSize+p.CriticalQueuesSize).String()
		cpuCapability = cpuPerQueue.String()
	}

	memoryCapabilityTotal := ""
	memoryCapability := ""
	memoryDeserved := ""
	memoryGuarantee := ""
	if p.MemoryLendingLimit != "" {
		memoryLendingLimit, err := resource.ParseQuantity(p.MemoryLendingLimit)
		if err != nil {
			return err
		}

		hierarchy = true
		memoryCapabilityTotal = utils.TimesQuantity(memoryPerQueue, p.QueueSize+p.ImpactingQueuesSize+p.CriticalQueuesSize).String()
		memoryCapability = memoryPerQueue.String()
		memoryPerQueue.Sub(memoryLendingLimit)
		memoryDeserved = memoryPerQueue.String()
	} else {
		memoryCapabilityTotal = utils.TimesQuantity(memoryPerQueue, p.QueueSize+p.ImpactingQueuesSize+p.CriticalQueuesSize).String()
		memoryCapability = memoryPerQueue.String()
	}

	obj := &unstructured.Unstructured{}
	obj.SetName("root")
	obj.SetAPIVersion("scheduling.volcano.sh/v1beta1")
	obj.SetKind("Queue")
	err = utils.Resources.Patch(ctx, obj, k8s.Patch{
		PatchType: types.MergePatchType,
		Data:      []byte(fmt.Sprintf(`{"spec":{"reclaimable": true, "deserved":null, "guarantee":null, "capability":{"cpu": %q, "memory": %q}}}`, cpuCapabilityTotal, memoryCapabilityTotal)),
	})
	if err != nil {
		return err
	}

	err = utils.Resources.Delete(ctx, &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "volcano-scheduler-configmap",
			Namespace: "volcano-system",
		},
	})
	if err != nil {
		return err
	}

	err = decoder.DecodeEach(ctx, strings.NewReader(utils.YamlWithArgs(initYaml, map[string]any{
		"gang":       p.Gang,
		"preemption": p.Preemption,
		"hierarchy":  hierarchy,
	})), decoder.CreateHandler(utils.Resources))
	if err != nil {
		return err
	}

	err = utils.RestartDeployment(ctx, utils.Resources, "volcano-scheduler", "volcano-system")
	if err != nil {
		return err
	}

	for i := range p.QueueSize {
		err := decoder.DecodeEach(ctx, strings.NewReader(utils.YamlWithArgs(initQueueYaml, map[string]any{
			"name":             fmt.Sprintf("long-term-research-%d", i),
			"cpuCapability":    cpuCapability,
			"memoryCapability": memoryCapability,
			"cpuDeserved":      cpuDeserved,
			"memoryDeserved":   memoryDeserved,
			"cpuGuarantee":     cpuGuarantee,
			"memoryGuarantee":  memoryGuarantee,
		})), decoder.CreateHandler(utils.Resources))
		if err != nil {
			return err
		}
	}

	for i := range p.ImpactingQueuesSize {
		err := decoder.DecodeEach(ctx, strings.NewReader(utils.YamlWithArgs(initQueueYaml, map[string]any{
			"name":             fmt.Sprintf("business-impacting-%d", i),
			"cpuCapability":    cpuCapability,
			"memoryCapability": memoryCapability,
			"cpuDeserved":      cpuDeserved,
			"memoryDeserved":   memoryDeserved,
			"cpuGuarantee":     cpuGuarantee,
			"memoryGuarantee":  memoryGuarantee,
		})), decoder.CreateHandler(utils.Resources))
		if err != nil {
			return err
		}
	}

	for i := range p.CriticalQueuesSize {
		err := decoder.DecodeEach(ctx, strings.NewReader(utils.YamlWithArgs(initQueueYaml, map[string]any{
			"name":             fmt.Sprintf("human-critical-%d", i),
			"cpuCapability":    cpuCapability,
			"memoryCapability": memoryCapability,
			"cpuDeserved":      cpuDeserved,
			"memoryDeserved":   memoryDeserved,
			"cpuGuarantee":     cpuGuarantee,
			"memoryGuarantee":  memoryGuarantee,
		})), decoder.CreateHandler(utils.Resources))
		if err != nil {
			return err
		}
	}
	return nil
}

func (p *VolcanoProvider) AddJobs(ctx context.Context) error {
	steps := []struct {
		queueSize    int
		jobsPerQueue int
		podsPerJob   int
		priority     string
		duration     string
		delay        time.Duration
	}{
		{p.QueueSize, p.JobsSizePerQueue, p.PodsSizePerJob, "long-term-research", p.PodDuration, 0},
		{p.ImpactingQueuesSize, p.ImpactingJobsSizePerQueue, p.ImpactingPodsSizePerJob, "business-impacting", p.ImpactingPodDuration, 5 * time.Second},
		{p.CriticalQueuesSize, p.CriticalJobsSizePerQueue, p.CriticalPodsSizePerJob, "human-critical", p.CriticalPodDuration, 5 * time.Second},
	}

	for _, step := range steps {
		if step.delay > 0 {
			time.Sleep(step.delay)
		}
		for i := range step.queueSize {
			for range step.jobsPerQueue {
				err := p.addSingleJobs(ctx, step.podsPerJob, i, step.priority, step.duration)
				if err != nil {
					return err
				}
			}
		}
	}
	return nil
}

func (p *VolcanoProvider) addSingleJobs(ctx context.Context, podSize int, queueIndex int, priority string, duration string) error {
	return decoder.DecodeEach(ctx, strings.NewReader(utils.YamlWithArgs(batchJobYaml, map[string]any{
		"name":                fmt.Sprintf("%s-%d", priority, queueIndex),
		"queue":               fmt.Sprintf("test-queue-%s-%d", priority, queueIndex),
		"size":                podSize,
		"index":               utils.Index(),
		"cpuRequestPerPod":    p.CpuRequestPerPod,
		"memoryRequestPerPod": p.MemoryRequestPerPod,
		"gang":                p.Gang,
		"priority":            priority,
		"preemption":          p.Preemption,
		"duration":            duration,
	})), decoder.CreateHandler(utils.Resources))
}
