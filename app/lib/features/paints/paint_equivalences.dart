/// Static cross-brand paint equivalence map.
/// Key format: 'brand:code'  →  list of (brand, code) equivalents.
/// Source: community equivalence tables (approximate, not spectrophotometric).
const Map<String, List<(String, String)>> kPaintEquivalences = {
  // ── Vallejo Model Color ────────────────────────────────────────────────────
  'vallejo:70.950': [('citadel', 'Abaddon Black'), ('tamiya', 'XF-1')],
  'vallejo:70.951': [('citadel', 'Corax White'), ('tamiya', 'XF-2')],
  'vallejo:70.947': [('citadel', 'Mephiston Red'), ('tamiya', 'XF-7')],
  'vallejo:70.963': [('citadel', 'Macragge Blue'), ('tamiya', 'XF-8')],
  'vallejo:70.880': [('citadel', 'Death World Forest'), ('tamiya', 'XF-58')],
  'vallejo:70.976': [('citadel', 'Castellan Green'), ('tamiya', 'XF-65')],
  'vallejo:70.916': [('citadel', 'Zandri Dust'), ('tamiya', 'XF-57')],
  'vallejo:70.875': [('citadel', 'Rakarth Flesh'), ('tamiya', 'XF-15')],
  'vallejo:70.918': [('citadel', 'Leadbelcher'), ('tamiya', 'XF-56')],
  'vallejo:70.997': [('citadel', 'Balthasar Gold'), ('tamiya', 'XF-6')],
  'vallejo:70.981': [('citadel', 'Averland Sunset'), ('tamiya', 'XF-3')],
  'vallejo:70.957': [('citadel', 'Bugman\'s Glow')],
  'vallejo:70.965': [('citadel', 'Incubi Darkness'), ('tamiya', 'XF-27')],
  'vallejo:70.900': [('citadel', 'Rhinox Hide'), ('tamiya', 'XF-10')],

  // ── Citadel → Vallejo reverse ─────────────────────────────────────────────
  'citadel:Abaddon Black': [('vallejo', '70.950'), ('tamiya', 'XF-1')],
  'citadel:Corax White': [('vallejo', '70.951'), ('tamiya', 'XF-2')],
  'citadel:Mephiston Red': [('vallejo', '70.947'), ('tamiya', 'XF-7')],
  'citadel:Macragge Blue': [('vallejo', '70.963'), ('tamiya', 'XF-8')],
  'citadel:Leadbelcher': [('vallejo', '70.918'), ('tamiya', 'XF-56')],
  'citadel:Balthasar Gold': [('vallejo', '70.997'), ('tamiya', 'XF-6')],
  'citadel:Averland Sunset': [('vallejo', '70.981'), ('tamiya', 'XF-3')],
  'citadel:Zandri Dust': [('vallejo', '70.916'), ('tamiya', 'XF-57')],
  'citadel:Death World Forest': [('vallejo', '70.880'), ('tamiya', 'XF-58')],
  'citadel:Castellan Green': [('vallejo', '70.976'), ('tamiya', 'XF-65')],

  // ── Tamiya → others ───────────────────────────────────────────────────────
  'tamiya:XF-1': [('vallejo', '70.950'), ('citadel', 'Abaddon Black')],
  'tamiya:XF-2': [('vallejo', '70.951'), ('citadel', 'Corax White')],
  'tamiya:XF-3': [('vallejo', '70.981'), ('citadel', 'Averland Sunset')],
  'tamiya:XF-6': [('vallejo', '70.997'), ('citadel', 'Balthasar Gold')],
  'tamiya:XF-7': [('vallejo', '70.947'), ('citadel', 'Mephiston Red')],
  'tamiya:XF-8': [('vallejo', '70.963'), ('citadel', 'Macragge Blue')],
  'tamiya:XF-10': [('vallejo', '70.900')],
  'tamiya:XF-56': [('vallejo', '70.918'), ('citadel', 'Leadbelcher')],
  'tamiya:XF-57': [('vallejo', '70.916'), ('citadel', 'Zandri Dust')],
  'tamiya:XF-58': [('vallejo', '70.880'), ('citadel', 'Death World Forest')],
  'tamiya:XF-65': [('vallejo', '70.976'), ('citadel', 'Castellan Green')],
};
