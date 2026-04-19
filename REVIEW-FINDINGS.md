# Review Findings

Check this file before every review to avoid rediscovering known items.

## Open

- [ ] WeatherSheet.swift (1239 lines) — extract CurrentWeatherCard and tooltip builders to separate files
- [ ] WeatherService has 25+ static utility functions — extract to WeatherDescriptions enum when convenient
- [ ] ContentView.swift (727 lines) — extract sheet modifiers and overlay logic
- [ ] No UI test coverage beyond app launch — add critical flow tests when test infrastructure improves
- [ ] No service fetch-path tests (VarsomService, WaterTemperatureService, RoutingService) — needs mock implementations
- [ ] Weather cache does not survive app restart — consider persisting last forecast to disk
- [ ] WeatherService/WaterTemperatureService/AirQualityService bypass APIClient retry logic — add retry on timeout

## Won't fix

- SchemaV2 version identifier is (1,1,0) not (2,0,0) — MUST NOT change, deployed users have this value in store metadata
- `try!` for regex in SearchService — literal patterns that cannot fail, acceptable Swift pattern
- `preferredColorScheme(.light)` hardcoded — intentional, map tiles designed for light backgrounds
- ConnectivityMonitor not injected via protocol — low testability impact, acceptable

## Fixed (v1.4.x, 19 April 2026)

- [x] nonisolated(unsafe) DateFormatters in VarsomService, WeatherService, WaterTemperatureService, KnowledgeArticle+GRDB
- [x] .white replaced with Color.Trakke.textInverse (7 sites)
- [x] .primary replaced with Color.Trakke.text (3 sites)
- [x] AirQualityService silent error swallowing — added Logger.weather.warning
- [x] Coordinate precision in RoutingService and WaterTemperatureService bathing spots
- [x] GDPR delete path missing knowledgeViewModel.deleteAllPacks()
- [x] Task without @MainActor in ContentView+Navigation
- [x] Save error alert shows first error message instead of hiding all
- [x] DateFormatter allocated per call in WeatherService.upcomingChange()
- [x] CLLocation heap allocation in TrakkeMapView.updateUIView replaced with Haversine
- [x] KartverketTileService style cache filename now includes version constant
- [x] OverlayLayer.tileURL returns nil for hillshading instead of preconditionFailure
- [x] GPX export write failure now logged
- [x] GPX XML header deduplicated into gpxDocument() helper
- [x] 3 annotation subclasses unified via IndexedPointAnnotation base class
- [x] Empty TrakkeWidgets directory removed
- [x] Hardcoded .title2 replaced with Font.Trakke.numeralLarge in OfflineChoiceSheet
- [x] Badge padding uses .Trakke.badgePadH/V tokens in DownloadManagerSheet
- [x] RemoteArticleService download URL uses sanitized filename
- [x] Accessibility hint on disabled route navigation button
