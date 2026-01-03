#!/bin/bash
set -eou pipefail

# Configuration
LAYER_NAME="dbt_layer"
PLATFORM="manylinux2014_aarch64"
LAMBDA_UNZIPPED_LIMIT_MB=250


# Read Python version from project root (parent directory)
if [ ! -f ".python-version" ]; then
    echo "Error: .python-version not found in project root. Make sure to run this script from the 'dbt' directory."
    exit 1
fi

PYTHON_VERSION=$(cat .python-version)

echo "--- Starting Lambda Layer Preparation: $LAYER_NAME ---"

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "Error: 'uv' is not installed. Please install it first."
    echo "Installation: pip install uv"
    exit 1
fi

# Generate requirements.txt from pyproject.toml using uv export
# See: https://stackoverflow.com/a/75886471 (Modified from community contributions)
echo "Generating requirements.txt from pyproject.toml..."
REQUIREMENTS_FILE="requirements.txt"

if uv export --no-hashes --no-header --no-annotate --format requirements-txt > "$REQUIREMENTS_FILE" 2>/dev/null; then
    echo "✓ requirements.txt generated successfully"
else
    echo "Error: Failed to generate requirements.txt"
    echo "Make sure you're running this from the project root or dbt directory"
    exit 1
fi

# Cleanup previous runs
echo "Cleaning up previous build artifacts..."
rm -rf python "${LAYER_NAME}.zip"

# Create build directory
mkdir -p python

# Install dependencies using pip
echo "Installing dependencies for Python $PYTHON_VERSION on $PLATFORM using pip..."
pip install \
    --platform "$PLATFORM" \
    --python-version "$PYTHON_VERSION" \
    --only-binary=:all: \
    --target python/ \
    --implementation cp \
    -r "$REQUIREMENTS_FILE"

# Optimization: Remove unnecessary files to reduce layer size
echo "Optimizing layer size..."

# Remove __pycache__ everywhere
find python/ -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

# Remove compiled files
find python/ -name "*.pyc" -delete
find python/ -name "*.pyo" -delete
find python/ -name "*.pyd" -delete
find python/ -name "*.exe" -delete

# Remove test files and documentation to save space
find python/ -type d -name "docs" -exec rm -rf {} + 2>/dev/null || true

# Remove entire .dist-info directories (not needed in Lambda layer)
find python/ -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true

# Check unzipped size
UNZIPPED_SIZE=$(du -sm python | cut -f1)
echo "Unzipped layer size: ${UNZIPPED_SIZE}MB"

if [ "$UNZIPPED_SIZE" -gt "$LAMBDA_UNZIPPED_LIMIT_MB" ]; then
    echo "WARNING: Unzipped size (${UNZIPPED_SIZE}MB) exceeds AWS Lambda limit (${LAMBDA_UNZIPPED_LIMIT_MB}MB)!"
    echo "Consider removing non-essential dependencies or using a different approach."
fi

# Create zip archive with maximum compression
echo "Creating zip archive with compression..."
zip -r9q "${LAYER_NAME}.zip" python

# Final stats
ZIPPED_SIZE=$(du -sh "${LAYER_NAME}.zip" | cut -f1)
echo ""
echo "--- Success! ---"
echo "Layer package: ${LAYER_NAME}.zip"
echo "Zipped size: $ZIPPED_SIZE"
echo "Unzipped size: ${UNZIPPED_SIZE}MB"

# Cleanup build directory
rm -rf python

# Remove generated requirements.txt
rm -f "$REQUIREMENTS_FILE"


echo "Layer is ready to be deployed!"
