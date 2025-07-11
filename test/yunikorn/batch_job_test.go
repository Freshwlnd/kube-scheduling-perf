package yunikorn_test

import (
	"context"
	"testing"

	"github.com/wzshiming/kube-scheduling-perf/test/utils"
)

func TestInit(t *testing.T) {
	err := provider.AddNodes(context.Background())
	if err != nil {
		t.Fatal(err)
	}

	err = provider.InitCase(context.Background())
	if err != nil {
		t.Fatal(err)
	}
}

func TestBatchJob(t *testing.T) {
	err := provider.AddJobs(context.Background())
	if err != nil {
		t.Fatal(err)
	}

	err = utils.WaitDeployment(context.Background(), utils.Resources)
	if err != nil {
		t.Fatal(err)
	}
}
