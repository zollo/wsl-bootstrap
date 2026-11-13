# shellcheck shell=bash disable=SC1090
# Shell completion for the pinned tools (only when present).
command -v kubectl >/dev/null && { source <(kubectl completion bash); complete -o default -F __start_kubectl k; }
command -v helm    >/dev/null && source <(helm completion bash)
command -v gh      >/dev/null && source <(gh completion -s bash)
command -v yq      >/dev/null && source <(yq shell-completion bash)
command -v tofu    >/dev/null && complete -C "$(command -v tofu)" tofu tf
command -v packer  >/dev/null && complete -C "$(command -v packer)" packer
