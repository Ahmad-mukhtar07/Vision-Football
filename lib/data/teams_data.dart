import '../models/team.dart';

/// Static roster of selectable international teams for Quick Match.
///
/// Attributes are FIFA-style 0–100. Edit freely — gameplay reads the
/// normalized values, so balancing happens here.
const Team brazil = Team(
  name: 'Brazil',
  countryCode: 'BR',
  overall: 88,
  shooters: [
    Player(name: 'Vinny Junior', overall: 89, power: 80, accuracy: 75, curve: 82),
    Player(name: 'Rodryggo Goes', overall: 86, power: 72, accuracy: 78, curve: 70),
    Player(name: 'Raffhinha', overall: 88, power: 70, accuracy: 72, curve: 85),
    Player(name: 'Lukas Paketa', overall: 82, power: 75, accuracy: 82, curve: 65),
    Player(name: 'Endrik', overall: 80, power: 88, accuracy: 70, curve: 60),
  ],
  keeper: GoalkeeperRating(
    name: 'Allisson Bekker',
    overall: 84,
    reflex: 90,
    prediction: 88,
  ),
);

const Team argentina = Team(
  name: 'Argentina',
  countryCode: 'AR',
  overall: 84,
  shooters: [
    Player(name: 'Leon Mesi', overall: 85, power: 82, accuracy: 96, curve: 95),
    Player(name: 'Lautro Martynz', overall: 81, power: 85, accuracy: 87, curve: 65),
    Player(name: 'Julien Alvarz', overall: 84, power: 81, accuracy: 85, curve: 72),
    Player(name: 'Alexi McAlester', overall: 82, power: 80, accuracy: 84, curve: 81),
    Player(name: 'Alejo Garnachio', overall: 80, power: 76, accuracy: 75, curve: 78),
  ],
  keeper: GoalkeeperRating(
    name: 'Emilio Martynz',
    overall: 89,
    reflex: 91,
    prediction: 92,
  ),
);

const Team portugal = Team(
  name: 'Portugal',
  countryCode: 'PT',
  overall: 87,
  shooters: [
    Player(name: 'Cristian Rinaldi', overall: 86, power: 91, accuracy: 89, curve: 76),
    Player(name: 'Bruno Fernancio', overall: 88, power: 87, accuracy: 86, curve: 85),
    Player(name: 'Bernardo Sylva', overall: 83, power: 68, accuracy: 90, curve: 86),
    Player(name: 'Rafa Leo', overall: 84, power: 81, accuracy: 76, curve: 73),
    Player(name: 'Joao Feliks', overall: 81, power: 75, accuracy: 81, curve: 84),
  ],
  keeper: GoalkeeperRating(
    name: 'Diogo Kostas',
    overall: 84,
    reflex: 88,
    prediction: 86,
  ),
);

const Team france = Team(
  name: 'France',
  countryCode: 'FR',
  overall: 89,
  shooters: [
    Player(name: 'Killian M\'Bape', overall: 91, power: 89, accuracy: 90, curve: 79),
    Player(name: 'Antwan Griezman', overall: 82, power: 77, accuracy: 88, curve: 86),
    Player(name: 'Usman Dembely', overall: 89, power: 75, accuracy: 74, curve: 81),
    Player(name: 'Mark Thuram', overall: 79, power: 83, accuracy: 80, curve: 64),
    Player(name: 'Bradley Barcla', overall: 85, power: 72, accuracy: 78, curve: 77),
  ],
  keeper: GoalkeeperRating(
    name: 'Mike Maygnan',
    overall: 88,
    reflex: 90,
    prediction: 89,
  ),
);

const Team england = Team(
  name: 'England',
  countryCode: 'GB-ENG',
  overall: 84,
  shooters: [
    Player(name: 'Harry Kaine', overall: 87, power: 91, accuracy: 94, curve: 75),
    Player(name: 'Jude Bellinghem', overall: 88, power: 83, accuracy: 87, curve: 74),
    Player(name: 'Bukayo Sakka', overall: 82, power: 77, accuracy: 85, curve: 82),
    Player(name: 'Phillip Fodden', overall: 84, power: 80, accuracy: 89, curve: 84),
    Player(name: 'Cole Palmier', overall: 85, power: 82, accuracy: 90, curve: 87),
  ],
  keeper: GoalkeeperRating(
    name: 'Jordon Pickfort',
    overall: 81,
    reflex: 86,
    prediction: 85,
  ),
);

const Team spain = Team(
  name: 'Spain',
  countryCode: 'ES',
  overall: 88,
  shooters: [
    Player(name: 'Lamine Jamal', overall: 88, power: 74, accuracy: 85, curve: 90),
    Player(name: 'Nico Williamz', overall: 82, power: 77, accuracy: 79, curve: 76),
    Player(name: 'Alvaro Morato', overall: 83, power: 80, accuracy: 82, curve: 62),
    Player(name: 'Daniel Olmon', overall: 82, power: 78, accuracy: 86, curve: 82),
    Player(name: 'Pedro Gonzales', overall: 84, power: 69, accuracy: 87, curve: 81),
  ],
  keeper: GoalkeeperRating(
    name: 'Unai Symon',
    overall: 88,
    reflex: 87,
    prediction: 88,
  ),
);

const Team germany = Team(
  name: 'Germany',
  countryCode: 'DE',
  overall: 85,
  shooters: [
    Player(name: 'Florian Virts', overall: 82, power: 76, accuracy: 88, curve: 85),
    Player(name: 'Jamal Musialah', overall: 84, power: 73, accuracy: 87, curve: 83),
    Player(name: 'Kai Havretz', overall: 81, power: 79, accuracy: 84, curve: 71),
    Player(name: 'Niklas Fullkrug', overall: 77, power: 88, accuracy: 83, curve: 59),
    Player(name: 'Leroy San', overall: 83, power: 83, accuracy: 77, curve: 82),
  ],
  keeper: GoalkeeperRating(
    name: 'Mark-Andre Ter Steegen',
    overall: 89,
    reflex: 89,
    prediction: 88,
  ),
);


const Team italy = Team(
  name: 'Italy',
  countryCode: 'IT',
  overall: 83,
  shooters: [
    Player(name: 'Federigo Chieza', overall: 83, power: 82, accuracy: 78, curve: 81),
    Player(name: 'Nikolo Barela', overall: 86, power: 78, accuracy: 76, curve: 80),
    Player(name: 'Lorenso Pelegrini', overall: 81, power: 77, accuracy: 79, curve: 83),
    Player(name: 'Janluca Skamaka', overall: 81, power: 87, accuracy: 80, curve: 68),
    Player(name: 'Jakomo Razpadori', overall: 79, power: 75, accuracy: 78, curve: 74),
  ],
  keeper: GoalkeeperRating(
    name: 'Janluigi Donaruma',
    overall: 87,
    reflex: 89,
    prediction: 85,
  ),
);

const Team belgium = Team(
  name: 'Belgium',
  countryCode: 'BE',
  overall: 82,
  shooters: [
    Player(name: 'Kevin De Broyna', overall: 90, power: 85, accuracy: 88, curve: 92),
    Player(name: 'Romelo Lukako', overall: 83, power: 88, accuracy: 81, curve: 72),
    Player(name: 'Leandri Trosard', overall: 82, power: 79, accuracy: 82, curve: 84),
    Player(name: 'Jeremi Dokku', overall: 81, power: 74, accuracy: 71, curve: 76),
    Player(name: 'Lowis Openda', overall: 82, power: 80, accuracy: 79, curve: 68),
  ],
  keeper: GoalkeeperRating(
    name: 'Tybo Kortwa',
    overall: 89,
    reflex: 89,
    prediction: 88,
  ),
);

const Team netherlands = Team(
  name: 'Netherlands',
  countryCode: 'NL',
  overall: 84,
  shooters: [
    Player(name: 'Kodi Jakpo', overall: 83, power: 81, accuracy: 82, curve: 83),
    Player(name: 'Memfis Depai', overall: 81, power: 82, accuracy: 79, curve: 84),
    Player(name: 'Zavi Symons', overall: 83, power: 76, accuracy: 78, curve: 81),
    Player(name: 'Frenky de Jonk', overall: 86, power: 68, accuracy: 75, curve: 78),
    Player(name: 'Doniel Maylen', overall: 81, power: 83, accuracy: 77, curve: 75),
  ],
  keeper: GoalkeeperRating(
    name: 'Bart Verbrugen',
    overall: 80,
    reflex: 82,
    prediction: 79,
  ),
);

const Team morocco = Team(
  name: 'Morocco',
  countryCode: 'MA',
  overall: 80,
  shooters: [
    Player(name: 'Brahim Dyaz', overall: 82, power: 75, accuracy: 79, curve: 80),
    Player(name: 'Yosef En-Nesri', overall: 80, power: 81, accuracy: 78, curve: 62),
    Player(name: 'Hakim Ziyek', overall: 79, power: 76, accuracy: 77, curve: 88),
    Player(name: 'Ashraf Hakimy', overall: 84, power: 77, accuracy: 72, curve: 74),
    Player(name: 'Amin Adly', overall: 78, power: 72, accuracy: 73, curve: 75),
  ],
  keeper: GoalkeeperRating(
    name: 'Yasine Bunu',
    overall: 84,
    reflex: 86,
    prediction: 84,
  ),
);

const Team norway = Team(
  name: 'Norway',
  countryCode: 'NO',
  overall: 78,
  shooters: [
    Player(name: 'Erlin Hailand', overall: 91, power: 93, accuracy: 91, curve: 77),
    Player(name: 'Martin Odegard', overall: 86, power: 76, accuracy: 82, curve: 87),
    Player(name: 'Aleksander Sorlot', overall: 80, power: 84, accuracy: 81, curve: 70),
    Player(name: 'Antonio Nussa', overall: 76, power: 68, accuracy: 70, curve: 74),
    Player(name: 'Oskar Bob', overall: 76, power: 65, accuracy: 72, curve: 75),
  ],
  keeper: GoalkeeperRating(
    name: 'Orian Niland',
    overall: 74,
    reflex: 76,
    prediction: 74,
  ),
);

const Team usa = Team(
  name: 'United States',
  countryCode: 'US',
  overall: 77,
  shooters: [
    Player(name: 'Kristian Pulisik', overall: 82, power: 76, accuracy: 79, curve: 78),
    Player(name: 'Florin Balogun', overall: 78, power: 78, accuracy: 77, curve: 66),
    Player(name: 'Wesly Mckenny', overall: 78, power: 76, accuracy: 70, curve: 65),
    Player(name: 'Gio Rayna', overall: 77, power: 72, accuracy: 74, curve: 78),
    Player(name: 'Timoty Wea', overall: 76, power: 74, accuracy: 71, curve: 70),
  ],
  keeper: GoalkeeperRating(
    name: 'Mat Turnor',
    overall: 76,
    reflex: 80,
    prediction: 75,
  ),
);

const Team croatia = Team(
  name: 'Croatia',
  countryCode: 'HR',
  overall: 82,
  shooters: [
    Player(name: 'Luka Modrik', overall: 83, power: 79, accuracy: 86, curve: 85),
    Player(name: 'Mateo Kovasich', overall: 83, power: 72, accuracy: 76, curve: 78),
    Player(name: 'Antte Budimyr', overall: 82, power: 82, accuracy: 80, curve: 64),
    Player(name: 'Andrej Kramarich', overall: 81, power: 80, accuracy: 82, curve: 77),
    Player(name: 'Yvan Perisich', overall: 79, power: 81, accuracy: 78, curve: 82),
  ],
  keeper: GoalkeeperRating(
    name: 'Dominik Livakovich',
    overall: 80,
    reflex: 83,
    prediction: 80,
  ),
);

const Team india = Team(
  name: 'India',
  countryCode: 'IN',
  overall: 98,
  shooters: [
    Player(name: 'Sunil Chetry', overall: 98, power: 98, accuracy: 84, curve: 91),
    Player(name: 'Virrat Kholi', overall: 92, power: 91, accuracy: 84, curve: 82),
    Player(name: 'Rohit Sharma', overall: 88, power: 87, accuracy: 91, curve: 76),
    Player(name: 'MS Dhoni', overall: 92, power: 79, accuracy: 83, curve: 99),
    Player(name: 'Ranveer Singh', overall: 81, power: 76, accuracy: 62, curve: 99),
  ],
  keeper: GoalkeeperRating(
    name: 'Gurpret Sing Sandhu',
    overall: 95,
    reflex: 83,
    prediction: 80,
  ),
);

const Team pakistan = Team(
  name: 'Pakistan',
  countryCode: 'PK',
  overall: 98,
  shooters: [
    Player(name: 'Otis Khan', overall: 98, power: 98, accuracy: 85, curve: 98),
    Player(name: 'Rahis Nabi', overall: 94, power: 87, accuracy: 95, curve: 98),
    Player(name: 'Shayak Dost', overall: 94, power: 95, accuracy: 96, curve: 73),
    Player(name: 'Alamgir Ghazi', overall: 93, power: 85, accuracy: 90, curve: 90),
    Player(name: 'Fareed Ullah', overall: 90, power: 80, accuracy: 99, curve: 96),
  ],
  keeper: GoalkeeperRating(
    name: 'Yousuf Butt',
    overall: 98,
    reflex: 85,
    prediction: 81,
  ),
);


/// Standard international teams shown first in the team picker.
const List<Team> kStandardTeams = [
  brazil,
  argentina,
  portugal,
  france,
  england,
  spain,
  germany,
  italy,
  belgium,
  netherlands,
  morocco,
  croatia,
  norway,
  usa,
];

/// Extra teams shown under a separate "Special Teams" section.
const List<Team> kSpecialTeams = [
  india,
  pakistan,
];

/// All teams shown in the team picker and available for Full Match.
///
/// When adding a new [Team] above, append it to [kStandardTeams] or
/// [kSpecialTeams] so it appears in-game.
const List<Team> kAllTeams = [
  ...kStandardTeams,
  ...kSpecialTeams,
];

/// Whether two [Team] values refer to the same selectable nation.
bool teamsMatch(Team a, Team b) =>
    a.countryCode.toUpperCase() == b.countryCode.toUpperCase();

/// Finds a team by ISO country code, or null if it is not selectable.
Team? teamForCountryCode(String countryCode) {
  final code = countryCode.toUpperCase();
  for (final team in kAllTeams) {
    if (team.countryCode.toUpperCase() == code) return team;
  }
  return null;
}
