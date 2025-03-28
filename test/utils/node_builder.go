package utils

import (
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"sigs.k8s.io/e2e-framework/pkg/envconf"
)

type NodeBuilder struct {
	node *corev1.Node
}

func NewNodeBuilder() *NodeBuilder {
	name := envconf.RandomName("kwok-node", 16)
	return &NodeBuilder{
		node: &corev1.Node{
			ObjectMeta: metav1.ObjectMeta{
				Name: name,
				Annotations: map[string]string{
					"node.alpha.kubernetes.io/ttl": "0",
					"kwok.x-k8s.io/node":           "fake",
				},
				Labels: map[string]string{
					"beta.kubernetes.io/arch":       "amd64",
					"beta.kubernetes.io/os":         "linux",
					"kubernetes.io/arch":            "amd64",
					"kubernetes.io/hostname":        name,
					"kubernetes.io/os":              "linux",
					"kubernetes.io/role":            "agent",
					"node-role.kubernetes.io/agent": "",
					"type":                          "kwok",
				},
			},
			Spec: corev1.NodeSpec{
				Taints: []corev1.Taint{
					{
						Key:    "kwok.x-k8s.io/node",
						Value:  "fake",
						Effect: corev1.TaintEffectNoSchedule,
					},
				},
			},
			Status: corev1.NodeStatus{
				Allocatable: corev1.ResourceList{
					"cpu":    resource.MustParse("32"),
					"memory": resource.MustParse("256Gi"),
					"pods":   resource.MustParse("110"),
				},
				Capacity: corev1.ResourceList{
					"cpu":    resource.MustParse("32"),
					"memory": resource.MustParse("256Gi"),
					"pods":   resource.MustParse("110"),
				},
			},
		},
	}
}

func (b *NodeBuilder) WithName(name string) *NodeBuilder {
	b.node.Name = name
	b.node.Labels["kubernetes.io/hostname"] = name
	return b
}

func (b *NodeBuilder) WithFastReady() *NodeBuilder {
	b.node.Status.Conditions = []corev1.NodeCondition{
		{
			Type:               corev1.NodeReady,
			Status:             corev1.ConditionTrue,
			Reason:             "KubeletReady",
			Message:            "kubelet is posting ready status",
			LastHeartbeatTime:  metav1.Now(),
			LastTransitionTime: metav1.Now(),
		},
	}
	b.node.Status.Phase = corev1.NodeRunning
	return b
}

func (b *NodeBuilder) WithCPU(cpu string) *NodeBuilder {
	b.node.Status.Allocatable["cpu"] = resource.MustParse(cpu)
	return b
}

func (b *NodeBuilder) WithMemory(memory string) *NodeBuilder {
	b.node.Status.Allocatable["memory"] = resource.MustParse(memory)
	return b
}

func (b *NodeBuilder) Build() *corev1.Node {
	return b.node.DeepCopy()
}
