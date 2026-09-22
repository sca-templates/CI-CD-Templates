# Changelog

## [2.4.2](https://github.com/sca-templates/CI-CD-Templates/compare/v2.4.1...v2.4.2) (2026-09-22)


### Bug Fixes

* **ci:** avoid reusable workflow concurrency collision ([#40](https://github.com/sca-templates/CI-CD-Templates/issues/40)) ([933e103](https://github.com/sca-templates/CI-CD-Templates/commit/933e103365e5ad000fe4a92008effd432e94e9db))

## [2.4.1](https://github.com/sca-templates/CI-CD-Templates/compare/v2.4.0...v2.4.1) (2026-09-22)


### Bug Fixes

* **ci:** inline PR label action into reusable workflow ([#38](https://github.com/sca-templates/CI-CD-Templates/issues/38)) ([852b60b](https://github.com/sca-templates/CI-CD-Templates/commit/852b60b28d0be8de348e84d98676ad186e93c4bd))

## [2.4.0](https://github.com/sca-templates/CI-CD-Templates/compare/v2.3.0...v2.4.0) (2026-09-21)


### Features

* **templates:** sync dev/qa apps via ArgoCD instead of deploy refs ([#34](https://github.com/sca-templates/CI-CD-Templates/issues/34)) ([e14f980](https://github.com/sca-templates/CI-CD-Templates/commit/e14f9801c8159cc6d38a99acb296d3f064f79683))

## [2.3.0](https://github.com/sca-templates/CI-CD-Templates/compare/v2.2.0...v2.3.0) (2026-09-21)


### Features

* **workflows:** enable the ApplicationSet list registry expressions ([#32](https://github.com/sca-templates/CI-CD-Templates/issues/32)) ([6d0c0cf](https://github.com/sca-templates/CI-CD-Templates/commit/6d0c0cf4f90a764862570bbe3d350dcc6733b0f1))

## [2.2.0](https://github.com/sca-templates/CI-CD-Templates/compare/v2.1.0...v2.2.0) (2026-09-20)


### Features

* **ci:** promote selected refs with QA approval gate ([#30](https://github.com/sca-templates/CI-CD-Templates/issues/30)) ([276ff28](https://github.com/sca-templates/CI-CD-Templates/commit/276ff2821c56a8ac24564bc48f03622d55d2b3b1))

## [2.1.0](https://github.com/sca-templates/CI-CD-Templates/compare/v2.0.1...v2.1.0) (2026-09-20)


### Features

* **ci:** add latest promotion workflow and update release config ([#28](https://github.com/sca-templates/CI-CD-Templates/issues/28)) ([6c047b9](https://github.com/sca-templates/CI-CD-Templates/commit/6c047b9d3246235cf8bdb1f75022f09639f7e2ad))

## [2.0.1](https://github.com/sca-templates/CI-CD-Templates/compare/v2.0.0...v2.0.1) (2026-09-20)


### Bug Fixes

* **ci:** scope workflow permissions to jobs ([#22](https://github.com/sca-templates/CI-CD-Templates/issues/22)) ([0601d9e](https://github.com/sca-templates/CI-CD-Templates/commit/0601d9ec66c322d9d4f554e9c05b934a26ddfec1))

## [2.0.0](https://github.com/sca-templates/CI-CD-Templates/compare/v1.1.1...v2.0.0) (2026-09-20)


### ⚠ BREAKING CHANGES

* **deploy:** shared-gitops-promote.yml and gitops-bump-image are removed; consumers must migrate to shared-service-promote/adopt-prod/enforce-latest.

### Features

* **deploy:** replace GitOps promote with deploy model ([#19](https://github.com/sca-templates/CI-CD-Templates/issues/19)) ([55f1379](https://github.com/sca-templates/CI-CD-Templates/commit/55f1379db6dea5dd649581cae0fbcd3031a14389))

## [1.1.1](https://github.com/sca-templates/CI-CD-Templates/compare/v1.1.0...v1.1.1) (2026-09-18)


### Bug Fixes

* **ci:** exclude CHANGELOG.md from markdown link checker ([#17](https://github.com/sca-templates/CI-CD-Templates/issues/17)) ([6739463](https://github.com/sca-templates/CI-CD-Templates/commit/6739463ef67ff775b8b84b257b28ca3070912360))

## [1.1.0](https://github.com/sca-templates/CI-CD-Templates/compare/v1.0.0...v1.1.0) (2026-09-18)


### Features

* **ci:** add PR labeling, stale, and release automations ([#15](https://github.com/sca-templates/CI-CD-Templates/issues/15)) ([d8d2d71](https://github.com/sca-templates/CI-CD-Templates/commit/d8d2d71a240aeef2aaffe18247b162411198c438))

## 1.0.0 (2026-09-14)


### Features

* **ci:** add gitops promotion workflow and composite actions ([37040ab](https://github.com/sca-templates/CI-CD-Templates/commit/37040ab85ed49f2748cc1239b4ae65755cbbea31))
* **ci:** add optional docker publish to reusable workflows ([#1](https://github.com/sca-templates/CI-CD-Templates/issues/1)) ([e25e90f](https://github.com/sca-templates/CI-CD-Templates/commit/e25e90fa4bd8c43a5f68ba6076b4270db0151548))
* **ci:** add shared workflows for validation, security, and release ([84ea03d](https://github.com/sca-templates/CI-CD-Templates/commit/84ea03d41d4e2e4e77cb72c99803e2b7057a6451))
* **templates:** add stack-node and stack-nest reusable workflows ([3a048ce](https://github.com/sca-templates/CI-CD-Templates/commit/3a048cedc45ac792a0eafb2fdba54611fc57bd13))


### Bug Fixes

* **ci:** correct repo slug casing and stale naming in refs ([2b92239](https://github.com/sca-templates/CI-CD-Templates/commit/2b922399b801cc76917576444698efae8e7cd722))
