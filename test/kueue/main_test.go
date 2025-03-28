package kueue_test

import (
	"testing"

	"github.com/wzshiming/kube-scheduling-perf/test/utils"
)

var provider KueueProvider

func init() {
	provider.AddFlags()
}

func TestMain(m *testing.M) {
	utils.InitTestMain(m)
}
