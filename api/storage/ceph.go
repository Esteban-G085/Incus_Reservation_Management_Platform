package storage

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

func InitCeph() error {
	if _, err := exec.LookPath("rados"); err != nil {
		return fmt.Errorf("comando rados no encontrado: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	_, err := radosWithContext(ctx, "ls")
	if err != nil {
		fmt.Printf("WARNING: Ceph no disponible en inicio (continuando): %v\n", err)
	}
	return nil
}

const (
	poolName    = "reservas-pool"
	cephName    = "client.reservas"
	cephConf    = "/etc/ceph/ceph.conf"
	cephKeyring = "/etc/ceph/ceph.client.reservas.keyring"
	cmdTimeout  = 30 * time.Second
)

func radosWithContext(ctx context.Context, args ...string) (string, error) {
	cmdArgs := []string{"-p", poolName, "--name", cephName, "--conf", cephConf, "--keyring", cephKeyring}
	cmdArgs = append(cmdArgs, args...)
	cmd := exec.CommandContext(ctx, "rados", cmdArgs...)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &out
	err := cmd.Run()
	if err != nil {
		return "", fmt.Errorf("rados error: %w\n%s", err, strings.TrimSpace(out.String()))
	}
	return strings.TrimSpace(out.String()), nil
}

func rados(args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), cmdTimeout)
	defer cancel()
	return radosWithContext(ctx, args...)
}

func UploadFile(oid string, data []byte) error {
	ctx, cancel := context.WithTimeout(context.Background(), cmdTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "rados",
		"-p", poolName,
		"--name", cephName,
		"--conf", cephConf,
		"--keyring", cephKeyring,
		"put", oid, "-",
	)
	cmd.Stdin = bytes.NewReader(data)
	var out bytes.Buffer
	cmd.Stderr = &out
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("error subiendo archivo a Ceph: %w\n%s", err, strings.TrimSpace(out.String()))
	}
	return nil
}

func DownloadFile(oid string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), cmdTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "rados",
		"-p", poolName,
		"--name", cephName,
		"--conf", cephConf,
		"--keyring", cephKeyring,
		"get", oid, "-",
	)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &out
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("error descargando archivo de Ceph: %w\n%s", err, strings.TrimSpace(out.String()))
	}
	return out.Bytes(), nil
}

func DeleteFile(oid string) error {
	_, err := rados("rm", oid)
	return err
}

func ListFiles() ([]string, error) {
	out, err := rados("ls")
	if err != nil {
		return nil, err
	}
	if out == "" {
		return []string{}, nil
	}
	return strings.Split(out, "\n"), nil
}
