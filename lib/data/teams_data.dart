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
  countryCode: 'GB',
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

const Team pakistan = Team(
  name: 'Pakistan',
  countryCode: 'PK',
  overall: 68,
  shooters: [
    Player(name: 'Otis Khan', overall: 75, power: 65, accuracy: 70, curve: 72),
    Player(name: 'Rahis Nabi', overall: 67, power: 67, accuracy: 65, curve: 68),
    Player(name: 'Shayak Dost', overall: 64, power: 63, accuracy: 66, curve: 63),
    Player(name: 'Alamgir Ghazi', overall: 62, power: 61, accuracy: 64, curve: 60),
    Player(name: 'Fareed Ullah', overall: 63, power: 69, accuracy: 63, curve: 56),
  ],
  keeper: GoalkeeperRating(
    name: 'Yousuf Butt',
    overall: 73,
    reflex: 74,
    prediction: 72,
  ),
);

/// All teams available in the selection screen.
const List<Team> kAllTeams = [
  brazil,
  argentina,
  portugal,
  france,
  england,
  spain,
  germany,
  pakistan,
];
