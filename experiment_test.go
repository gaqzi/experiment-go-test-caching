package experiment_test

import (
	"os"
	"testing"
	"time"
)

func TestNotCachingDueToEnvVariable(t *testing.T) {
	t.Logf("Current value of DRONE_COMMIT_SHA=%q, time=%q", os.Getenv("DRONE_COMMIT_SHA"), time.Now())
}

func TestDoesntUseEnvVar(t *testing.T) {
	t.Logf("Current time=%q", time.Now())
}
