package package_test

import (
	"testing"
	"time"
)

func TestInAnotherPackage(t *testing.T) {
	t.Logf("A test in another package is not invalidated? time=%q", time.Now())
}
