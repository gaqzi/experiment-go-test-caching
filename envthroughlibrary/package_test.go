package envthroughlibrary_test

import (
	"testing"
	"time"

	"github.com/gaqzi/experiment-go-test-caching/submodule"
)

func TestThatUsesLibraryAnotherModule(t *testing.T) {
	submodule.Library()
	t.Logf("Depends on a setup function in a different module, time=%q", time.Now())
}
