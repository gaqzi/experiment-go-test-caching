package submodule

import (
	"log/slog"
	"os"
)

func Library() {
	sha := os.Getenv("DRONE_COMMIT_SHA")
	slog.Info("Calling library", "DRONE_COMMIT_SHA", sha)
}
