package experiment_test

import (
	"testing"
	"time"
)

func TestInSamePackageIsInvalidated(t *testing.T) {
	t.Logf("A test in the same package is also invalidated time=%q", time.Now())
}
