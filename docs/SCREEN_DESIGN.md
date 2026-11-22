# Design system (V2)
- Visual identity: white and soft-lavender workspace, high contrast ink text, vibrant purple/blue gradients, understated borders.
- Layout: 245px desktop sidebar, responsive mobile drawer, fixed topbar, maximum 1210px content width.
- Components: SurfaceCard, SectionTitle, FeatureTile, PageIntro, SmallLabel, InlineError.
- Frontend Clean Architecture: UI never contains raw HTTP or SQL. UI calls repository through Riverpod providers.
- Approved PB-V1 remains six primary screen boundaries. Input Studio and AI Review are styled pending states, not fake backend features.
- Approved eight stage names are preserved verbatim.
