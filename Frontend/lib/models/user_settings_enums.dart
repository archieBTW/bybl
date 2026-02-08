enum Denomination {
  catholic('Catholic'),
  evangelical('Evangelical'),
  mainlineProtestant('Mainline Protestant'),
  orthodox('Orthodox'),
  reformed('Reformed'),
  pentecostal('Pentecostal'),
  anglican('Anglican'),
  lutheran('Lutheran'),
  baptist('Baptist'),
  methodist('Methodist'),
  presbyterian('Presbyterian'),
  nondenominational('Non-denominational'),
  agnostic('Agnostic/Seeker'),
  atheist('Atheist/Critical'),
  jewish('Jewish'),
  muslim('Muslim'),
  seventhDayAdventist('Seventh-day Adventist'),
  latterDaySaint('Latter-day Saint (LDS)'),
  messianicJewish('Messianic Jewish'),
  assemblyOfGod('Assemblies of God'),
  churchOfChrist('Church of Christ'),
  nazarene('Nazarene'),
  quaker('Quaker'),
  anabaptist('Anabaptist/Mennonite'),
  copticOrthodox('Coptic Orthodox'),
  other('Other');

  final String label;
  const Denomination(this.label);
}

enum AIContext {
  academic('Academic/Critical'),
  devotional('Devotional/Spiritual'),
  pastoral('Pastoral/Counseling'),
  apologetic('Apologetic'),
  historical('Historical/Cultural'),
  linguistic('Linguistic (Greek/Hebrew)'),
  theological('Theological (Systematic)'),
  comparative('Comparative Religion'),
  mystical('Mystical/Contemplative'),
  practical('Practical Application');

  final String label;
  const AIContext(this.label);
}
