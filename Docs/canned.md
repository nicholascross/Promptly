# Canned prompts

## Overview

Canned prompts are reusable prompt snippets that you can apply to input or an interactive session. Promptly ships bundled canned prompts and loads them on demand. You can add or override prompts by placing text files in `~/.config/promptly/canned/`.

## Use canned prompts

```bash
echo "some input" | promptly --canned example
promptly --canned example --canned review
```

You can also use the short flag `-p` in place of `--canned`.

## Manage canned prompts

```bash
promptly canned list
promptly canned add example --content "Your canned prompt text"
promptly canned remove example
```

## Related docs

- [Configuration](configuration.md)
