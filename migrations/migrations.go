// Package migrations embeds the SQL schema files so binaries carry
// their own schema and can migrate on startup.
package migrations

import "embed"

// FS exposes the embedded SQL files.
//
//go:embed *.sql
var FS embed.FS
