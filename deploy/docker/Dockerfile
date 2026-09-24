# Single multi stage Dockerfile for every service. The build argument
# SERVICE selects which binary to compile, so the four images share
# layers and the build setup stays in one place.
FROM golang:1.26-alpine AS build

ARG SERVICE
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/service ./cmd/${SERVICE}

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /out/service /service

USER nonroot
ENTRYPOINT ["/service"]
