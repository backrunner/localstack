.PHONY: build test test-packaging install-local install-coordinator uninstall-coordinator package-app package-dmg release-dmg install-app assets clean

build:
	zsh -c 'source Scripts/swift_env.sh; swift build -c release'
	cargo build --manifest-path cli/Cargo.toml --release

test:
	zsh -c 'source Scripts/swift_env.sh; swift test'
	cargo test --manifest-path cli/Cargo.toml
	npm --prefix packages/unplugin-localstack test

test-packaging:
	python3 -m unittest discover -s Tests/PackagingTests -v

install-local:
	cargo install --path cli --root "$${HOME}/.local"

install-coordinator:
	Scripts/install_coordinator.sh

uninstall-coordinator:
	Scripts/uninstall_coordinator.sh

package-app:
	Scripts/package_app.sh

package-dmg:
	Scripts/package_dmg.sh

release-dmg:
	RELEASE=1 Scripts/package_dmg.sh

install-app:
	Scripts/install_app.sh

assets:
	Scripts/generate_assets.sh

clean:
	swift package clean
	cargo clean --manifest-path cli/Cargo.toml
