package main

import (
	"context"
	"log"
	"net/http"

	"mop-api/internal"
	"mop-api/internal/store"
)

func main() {
	cfg := internal.LoadConfig()
	st, err := store.NewSQLiteStore(cfg.DBPath)
	if err != nil {
		log.Fatal(err)
	}
	defer func() { _ = st.Close() }()
	if err := st.SeedBuiltinAppUser(context.Background()); err != nil {
		log.Printf("seed builtin app user: %v", err)
	}
	router := internal.NewRouter(cfg, st)
	log.Printf("mop-api listening on :%s", cfg.Port)
	if err := http.ListenAndServe(":"+cfg.Port, router); err != nil {
		log.Fatal(err)
	}
}
