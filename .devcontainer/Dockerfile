FROM mcr.microsoft.com/devcontainers/go:1.26-bookworm

RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    make \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*
# Instale dependências adicionais se necessário
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest \
    && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest \
    && go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest

RUN curl -fsSL https://dl.k6.io/key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/k6-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list \
    && sudo apt-get update && sudo apt-get install -y k6 \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    k6 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /go/pkg/mod /go/cache \
    && chown -R vscode:vscode /go

WORKDIR /workspace
COPY ../ /workspace

CMD ["make", "up"]
