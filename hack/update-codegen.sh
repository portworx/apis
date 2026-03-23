#!/usr/bin/env bash

# Copyright Pure Storage, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script generates deepcopy functions for the API types.
# It uses the kube_codegen.sh helpers from k8s.io/code-generator.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# Match the code-generator version to the k8s.io/apimachinery version in go.mod.
# Both come from the same Kubernetes release.
CODEGEN_VERSION=$(go list -m -f '{{.Version}}' k8s.io/apimachinery)

echo "Installing deepcopy-gen@${CODEGEN_VERSION}..."
go install "k8s.io/code-generator/cmd/deepcopy-gen@${CODEGEN_VERSION}"

GOBIN="$(go env GOBIN)"
if [[ -z "${GOBIN}" ]]; then
    GOBIN="$(go env GOPATH)/bin"
fi

# Collect all packages that have +k8s:deepcopy-gen tags
INPUT_PKGS=()
while IFS= read -r dir; do
    pkg="$(cd "${dir}" && GO111MODULE=on go list -find .)"
    INPUT_PKGS+=("${pkg}")
done < <(
    grep -r -l --include='*.go' '+k8s:deepcopy-gen=' "${SCRIPT_ROOT}" \
        --exclude-dir=vendor \
        --exclude-dir=.git \
    | while IFS= read -r f; do dirname "$f"; done \
    | sort -u
)

if [[ "${#INPUT_PKGS[@]}" -eq 0 ]]; then
    echo "No packages found with +k8s:deepcopy-gen tags."
    exit 0
fi

echo "Generating deepcopy code for ${#INPUT_PKGS[@]} package(s):"
printf "  %s\n" "${INPUT_PKGS[@]}"

# Remove old generated files before regenerating
find "${SCRIPT_ROOT}" -name zz_generated.deepcopy.go -not -path '*/vendor/*' -delete

"${GOBIN}/deepcopy-gen" \
    --output-file zz_generated.deepcopy.go \
    --go-header-file "${SCRIPT_ROOT}/hack/boilerplate.go.txt" \
    "${INPUT_PKGS[@]}"

echo "Code generation complete."

