# Configuration

1. Create the Config File
   ```bash
   mkdir -p ~/.config/promptly
   touch ~/.config/promptly/config.json
   ```

2. Example Configuration
   ```json
   {
     "model": "o4-mini",
     "provider": "openai",
     "providers": {
       "openai": {
         "name": "OpenAI",
         "baseURL": "https://api.openai.com/v1",
         "envKey": "OPENAI_API_KEY"
       },
       "azure": {
         "name": "AzureOpenAI",
         "baseURL": "https://YOUR_PROJECT_NAME.openai.azure.com/openai",
         "envKey": "AZURE_OPENAI_API_KEY"
       },
       "openrouter": {
         "name": "OpenRouter",
         "baseURL": "https://openrouter.ai/api/v1",
         "envKey": "OPENROUTER_API_KEY"
       },
       "gemini": {
         "name": "Gemini",
         "baseURL": "https://generativelanguage.googleapis.com/v1beta/openai",
         "envKey": "GEMINI_API_KEY"
       },
       "ollama": {
         "name": "Ollama",
         "baseURL": "http://localhost:11434/v1",
         "envKey": "OLLAMA_API_KEY"
       },
       "mistral": {
         "name": "Mistral",
         "baseURL": "https://api.mistral.ai/v1",
         "envKey": "MISTRAL_API_KEY"
       },
       "deepseek": {
         "name": "DeepSeek",
         "baseURL": "https://api.deepseek.com",
         "envKey": "DEEPSEEK_API_KEY"
       },
       "xai": {
         "name": "xAI",
         "baseURL": "https://api.x.ai/v1",
         "envKey": "XAI_API_KEY"
       },
       "groq": {
         "name": "Groq",
         "baseURL": "https://api.groq.com/openai/v1",
         "envKey": "GROQ_API_KEY"
       },
       "arceeai": {
         "name": "ArceeAI",
         "baseURL": "https://conductor.arcee.ai/v1",
         "envKey": "ARCEEAI_API_KEY"
       }
     }
   }
   ```

3. Parameter Overview
   - model: Model identifier.
   - provider: Selected provider key. Must match one of the entries in the `providers` map.
   - providers: Map of provider configurations. Each entry contains:
     - name: Human-readable name of the provider.
     - baseURL: Full base URL for the provider API (may include path prefix). **(If baseURL is specified, other URL components (scheme, host, port, path) should not be used.)**
     - scheme: URL scheme (e.g., http or https).
     - host: API host address.
     - port: API port number.
     - path: API path prefix (e.g., v1/chat/completions).
     - envKey: Environment variable name to read the API token from. **(Mutually exclusive with tokenName)**
     - tokenName: Keychain account name for reading the API token. **(Mutually exclusive with envKey)**
   - organizationId (optional): Your organization ID for OpenAI-compatible APIs.
   - rawOutput (default: false): When true, the raw response stream is output.

## Using llama.cpp

Launch the llama server:
```bash
llama-server -hf bartowski/DeepSeek-R1-Distill-Qwen-32B-GGUF
```

Example config (no token required):
```json
{
  "provider": "llama",
  "providers": {
    "llama": {
      "name": "llama",
      "scheme": "http",
      "host": "localhost",
      "port": 8080,
      "path": "v1/chat/completions"
    }
  }
}
```

## Using Ollama

Example config:
```json
{
  "provider": "ollama",
  "providers": {
    "ollama": {
      "name": "Ollama",
      "baseURL": "http://localhost:11434/v1",
      "tokenName": "ollama"
    }
  }
}
```

## Using OpenAI

Example config:
```json
{
  "provider": "openai",
  "organizationId": "org-123",
  "model": "gpt-4o-mini",
  "providers": {
    "openai": {
      "name": "OpenAI",
      "baseURL": "https://api.openai.com/v1",
      "tokenName": "openai"
    }
  }
}
```

## Using OpenWebUI

Example config:
```json
{
  "provider": "openwebui",
  "providers": {
    "openwebui": {
      "name": "OpenWebUI",
      "baseURL": "http://localhost:9000/api",
      "tokenName": "openwebui"
    }
  }
}
```
