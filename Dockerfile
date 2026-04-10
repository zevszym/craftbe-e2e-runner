FROM node:22-bookworm

# Playwright browsers location (shared, user-independent)
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

# Install Playwright Chromium + system dependencies
ARG PLAYWRIGHT_VERSION=1.58.2
RUN npx -y playwright@${PLAYWRIGHT_VERSION} install --with-deps chromium

# Extra tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    jq sudo curl \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Runner user (GH Actions runner refuses to run as root)
RUN useradd -m -s /bin/bash runner \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# GitHub Actions runner
ARG RUNNER_VERSION=2.333.1
ARG RUNNER_ARCH=x64
WORKDIR /home/runner/actions-runner
RUN curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" \
    | tar xz \
    && ./bin/installdependencies.sh

# Allure + Wrangler (used for R2 report uploads)
RUN npm install -g allure-commandline wrangler

# Everything under /home/runner owned by runner
RUN chown -R runner:runner /home/runner

COPY entrypoint.sh /home/runner/entrypoint.sh
RUN chmod +x /home/runner/entrypoint.sh

# Start as root — entrypoint fixes volume permissions then drops to runner
ENTRYPOINT ["/home/runner/entrypoint.sh"]
