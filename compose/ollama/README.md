# Ollama

Atlas runs a CPU-only Ollama service with `qwen3:4b`. The model is about
2.5 GB and has stronger multilingual, reasoning, and agent capabilities than
the previous small model, making it a practical starting point for the
heating-node-generation workflow without requiring a GPU.

## Access

- LAN and Tailnet clients: `https://ollama.max-petri.xyz/api`
- n8n workflows: `http://ollama:11434/api`

The API has no built-in authentication. Caddy only exposes it to the home LAN
and trusted Tailnet, and n8n reaches it over a private Docker network. Do not
add a public DNS record, Fritz!Box port forward, or a public firewall rule for
this service.

## Start and verify

Apply the NixOS configuration first: it creates the shared private Docker
network used by n8n and Ollama. Then start Ollama; `model-bootstrap` downloads
the configured model when it is not already present. n8n may be started before
or after Ollama.

To call the service from a browser or another LAN/Tailnet client, also add the
same split-DNS records used by the other Atlas services for
`ollama.max-petri.xyz`. n8n itself needs no DNS record because it uses the
private Docker address above.

```bash
cd /etc/nixos/compose/ollama
sudo docker compose up -d
sudo docker compose ps
sudo docker compose logs --tail=100 model-bootstrap
sudo docker compose exec ollama ollama list
curl --fail https://ollama.max-petri.xyz/api/tags
```

`model-bootstrap` exits successfully after the model is present; this is
expected. Model files are persisted in `/srv/containers/ollama`, so ordinary
container recreation does not re-download them.

## n8n request

Use n8n's HTTP Request node with `POST http://ollama:11434/api/chat`, JSON
body, and a sufficiently long node timeout for CPU inference. For example:

```json
{
  "model": "qwen3:4b",
  "stream": false,
  "format": "json",
  "messages": [
    {
      "role": "system",
      "content": "Return only valid JSON matching the requested schema."
    },
    {
      "role": "user",
      "content": "Create the requested heating-node configuration."
    }
  ]
}
```

The generated text is returned at `message.content`. Validate that JSON and
the resulting heating configuration in n8n before any state-changing step.

## Model maintenance

To re-check or update the configured model intentionally, run:

```bash
cd /etc/nixos/compose/ollama
sudo docker compose run --rm model-bootstrap
sudo docker compose exec ollama ollama list
```

Model weights are reproducible downloads and are excluded from the proposed
backup scope. Account for their disk use under `/srv` before adding larger
models.
