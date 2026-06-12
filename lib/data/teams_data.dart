import '../models/team.dart';

/// Static roster of selectable international teams for Quick Match.
///
/// Attributes are FIFA-style 0–100. Edit freely — gameplay reads the
/// normalized values, so balancing happens here.
const Team brazil = Team(
  name: 'Brazil',
  countryCode: 'BR',
  shooters: [
    Player(name: 'Vinicius Jr', power: 80, accuracy: 75, curve: 82),
    Player(name: 'Rodrygo', power: 72, accuracy: 78, curve: 70),
    Player(name: 'Raphinha', power: 70, accuracy: 72, curve: 85),
    Player(name: 'Paquetá', power: 75, accuracy: 82, curve: 65),
    Player(name: 'Endrick', power: 88, accuracy: 70, curve: 60),
  ],
  keeper: GoalkeeperRating(name: 'Alisson', reflex: 90, prediction: 88),
);

const Team argentina = Team(
  name: 'Argentina',
  countryCode: 'AR',
  shooters: [
    Player(name: 'Lionel Messi', power: 82, accuracy: 96, curve: 95),
    Player(name: 'Lautaro Martínez', power: 85, accuracy: 87, curve: 65),
    Player(name: 'Julián Álvarez', power: 81, accuracy: 85, curve: 72),
    Player(name: 'Alexis Mac Allister', power: 80, accuracy: 84, curve: 81),
    Player(name: 'Alejandro Garnacho', power: 76, accuracy: 75, curve: 78),
  ],
  keeper: GoalkeeperRating(name: 'Emi Martínez', reflex: 91, prediction: 92),
);

const Team portugal = Team(
  name: 'Portugal',
  countryCode: 'PT',
  shooters: [
    Player(name: 'Cristiano Ronaldo', power: 91, accuracy: 89, curve: 76),
    Player(name: 'Bruno Fernandes', power: 87, accuracy: 86, curve: 85),
    Player(name: 'Bernardo Silva', power: 68, accuracy: 90, curve: 86),
    Player(name: 'Rafael Leão', power: 81, accuracy: 76, curve: 73),
    Player(name: 'João Félix', power: 75, accuracy: 81, curve: 84),
  ],
  keeper: GoalkeeperRating(name: 'Diogo Costa', reflex: 88, prediction: 86),
);

const Team france = Team(
  name: 'France',
  countryCode: 'FR',
  shooters: [
    Player(name: 'Kylian Mbappé', power: 89, accuracy: 90, curve: 79),
    Player(name: 'Antoine Griezmann', power: 77, accuracy: 88, curve: 86),
    Player(name: 'Ousmane Dembélé', power: 75, accuracy: 74, curve: 81),
    Player(name: 'Marcus Thuram', power: 83, accuracy: 80, curve: 64),
    Player(name: 'Bradley Barcola', power: 72, accuracy: 78, curve: 77),
  ],
  keeper: GoalkeeperRating(name: 'Mike Maignan', reflex: 90, prediction: 89),
);

const Team england = Team(
  name: 'England',
  countryCode: 'GB',
  shooters: [
    Player(name: 'Harry Kane', power: 91, accuracy: 94, curve: 75),
    Player(name: 'Jude Bellingham', power: 83, accuracy: 87, curve: 74),
    Player(name: 'Bukayo Saka', power: 77, accuracy: 85, curve: 82),
    Player(name: 'Phil Foden', power: 80, accuracy: 89, curve: 84),
    Player(name: 'Cole Palmer', power: 82, accuracy: 90, curve: 87),
  ],
  keeper: GoalkeeperRating(name: 'Jordan Pickford', reflex: 86, prediction: 85),
);

const Team spain = Team(
  name: 'Spain',
  countryCode: 'ES',
  shooters: [
    Player(name: 'Lamine Yamal', power: 74, accuracy: 85, curve: 90),
    Player(name: 'Nico Williams', power: 77, accuracy: 79, curve: 76),
    Player(name: 'Álvaro Morata', power: 80, accuracy: 82, curve: 62),
    Player(name: 'Dani Olmo', power: 78, accuracy: 86, curve: 82),
    Player(name: 'Pedri', power: 69, accuracy: 87, curve: 81),
  ],
  keeper: GoalkeeperRating(name: 'Unai Simón', reflex: 87, prediction: 88),
);

const Team germany = Team(
  name: 'Germany',
  countryCode: 'DE',
  shooters: [
    Player(name: 'Florian Wirtz', power: 76, accuracy: 88, curve: 85),
    Player(name: 'Jamal Musiala', power: 73, accuracy: 87, curve: 83),
    Player(name: 'Kai Havertz', power: 79, accuracy: 84, curve: 71),
    Player(name: 'Niclas Füllkrug', power: 88, accuracy: 83, curve: 59),
    Player(name: 'Leroy Sané', power: 83, accuracy: 77, curve: 82),
  ],
  keeper:
      GoalkeeperRating(name: 'Marc-André ter Stegen', reflex: 89, prediction: 88),
);

const Team pakistan = Team(
  name: 'Pakistan',
  countryCode: 'PK',
  shooters: [
    Player(name: 'Otis Khan', power: 65, accuracy: 70, curve: 72),
    Player(name: 'Rahis Nabi', power: 67, accuracy: 65, curve: 68),
    Player(name: 'Shayak Dost', power: 63, accuracy: 66, curve: 63),
    Player(name: 'Alamgir Ghazi', power: 61, accuracy: 64, curve: 60),
    Player(name: 'Fareed Ullah', power: 69, accuracy: 63, curve: 56),
  ],
  keeper: GoalkeeperRating(name: 'Yousuf Butt', reflex: 74, prediction: 72),
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
