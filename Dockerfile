FROM node:22-bookworm

# Playwright browsers location (shared, user-independent)
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

# Install Playwright Chromium + system dependencies
ARG PLAYWRIGHT_VERSION=1.58.2
RUN npx -y playwright@${PLAYWRIGHT_VERSION} install --with-deps chromium

# Extra tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    jq sudo \
    && rm -rf /var/lib/apt/lists/*

# Runner user (GH Actions runner cannot run as root)
RUN useradd -m -s /bin/bash runner \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# GitHub Actions runner
ARG RUNNER_VERSION=2.333.1
ARG RUNNER_ARCH=x64
WORKDIR /home/runner/actions-runner
RUN curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" \
    | tar xz \
    && ./bin/installdependencies.sh \
    && chown -R runner:runner /home/runner

# Allure for report generation
RUN npm install -g allure-commandline

COPY entrypoint.sh /home/runner/entrypoint.sh
RUN chmod +x /home/runner/entrypoint.sh

USER runner
WORKDIR /home/runner/actions-runner
ENTRYPOINT ["/home/runner/entrypoint.sh"]
