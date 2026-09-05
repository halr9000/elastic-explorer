# Steam Deck deployment — 2026-09-05

Native Linux x86-64 export, Godot 4.7.1 stable, Compatibility renderer.
Deployed through the paired SteamOS devkit to the separate ElasticExplorer title.
Remote executable SHA-256 matched the local export; a fresh exact-path process
was verified after launching through Steam's devkit RPC.

Hardware: AMD Custom APU 0405 / AMD Custom GPU 0405 (vangogh), SteamOS 3.8.16,
Mesa 25.3.0. The on-device sandbox expedition capture was 1280×800.
Its 180-frame timing sample reported 60 fps, median 16.706 ms and p95 17.054 ms.
The engine log contained no errors. This short stationary opening-scene sample
does not establish sustained expedition performance or battery consumption.

Local verification: five Godot test suites passed with zero failures, including
100 generated seeds. Python deployment scripts compiled; source identity checks
detected changed source, accepted restored source, and ignored build outputs.
The process guard passed Bash syntax checking and was exercised on the actual
Deck during repeated scoped deployments. SCRAPLINE remained registered.

The smoke run used a separate save sandbox. Normal launch opens the menu.
Hands-on Deck input, audio quality, suspend/resume, and complete expedition play
remain unverified. Capture and export logs are under ignored `test-results/`.
