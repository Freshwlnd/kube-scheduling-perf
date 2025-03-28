package yunikorn_test

import (
	"testing"

	"github.com/wzshiming/kube-scheduling-perf/test/utils"
)

func TestInit(t *testing.T) {
	err := provider.AddNodes(t.Context())
	if err != nil {
		t.Fatal(err)
	}

	err = provider.InitCase(t.Context())
	if err != nil {
		t.Fatal(err)
	}
}

func TestBatchJob(t *testing.T) {
	err := provider.AddJobs(t.Context())
	if err != nil {
		t.Fatal(err)
	}

	err = utils.WaitDeployment(t.Context(), utils.Resources)
	if err != nil {
		t.Fatal(err)
	}
}
