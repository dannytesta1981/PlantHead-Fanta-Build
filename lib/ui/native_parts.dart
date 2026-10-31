import 'package:flutter/material.dart';
import '../data/models.dart';

const fantaBlue = Color(0xff285bd7);
String metric(num? value) => value?.toString() ?? '—';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Color(0xff142b50),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle!,
              style: const TextStyle(fontSize: 12, color: Color(0xff65758d)),
            ),
          ),
      ],
    ),
  );
}

class TeamBadge extends StatelessWidget {
  const TeamBadge({super.key, required this.name, this.url, this.size = 42});
  final String name;
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xffeaf0fc),
      borderRadius: BorderRadius.circular(size / 2),
      border: Border.all(color: const Color(0xffd4dff4)),
    ),
    padding: const EdgeInsets.all(6),
    child: url == null
        ? _initial()
        : Image.network(
            url!,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, error, stack) => _initial(),
          ),
  );
  Widget _initial() => Center(
    child: Text(
      name.isEmpty ? 'PH' : name.characters.first.toUpperCase(),
      style: TextStyle(
        fontSize: size * .35,
        color: fantaBlue,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class EmptySection extends StatelessWidget {
  const EmptySection({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.onOpen,
  });
  final IconData icon;
  final String title, message;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xffe1e7f2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: fantaBlue, size: 30),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          style: const TextStyle(fontSize: 13, color: Color(0xff61738b)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('Apri sezione web'),
        ),
      ],
    ),
  );
}

class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.text, required this.onOpen});
  final String text;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xfffff5da),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(fontSize: 13)),
        TextButton(onPressed: onOpen, child: const Text('Verifica dal sito')),
      ],
    ),
  );
}

class TeamHero extends StatelessWidget {
  const TeamHero({
    super.key,
    required this.team,
    required this.onChoose,
    this.shirt,
  });
  final TeamData? team;
  final VoidCallback onChoose;
  final String? shirt;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff3777ef), Color(0xff142b70)],
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LA MIA SQUADRA',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        color: Color(0xffd1e0ff),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      team?.name ?? 'La tua squadra',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (team?.owner.isNotEmpty == true)
                      Text(
                        team!.owner,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xffd1e0ff),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Scegli squadra',
                onPressed: onChoose,
                icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
              if (shirt != null)
                Image.network(
                  shirt!,
                  height: 112,
                  fit: BoxFit.contain,
                  errorBuilder: (_, e, s) => const _NeutralShirt(),
                )
              else
                const _NeutralShirt(),
            ],
          ),
        ),
        if (shirt == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Maglia non ancora disponibile',
              style: TextStyle(fontSize: 10, color: Color(0xffd1e0ff)),
            ),
          ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, c) => Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                for (final item in [
                  (team?.rank == null ? '—' : '${team!.rank}ª', 'Posizione'),
                  (metric(team?.points), 'Punti'),
                  (metric(team?.played), 'Partite'),
                  (metric(team?.total), 'Punti totali'),
                ])
                  SizedBox(
                    width: (c.maxWidth - 12) / 2,
                    child: Column(
                      children: [
                        Text(
                          item.$1,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff173d82),
                          ),
                        ),
                        Text(
                          item.$2,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xff65758d),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _NeutralShirt extends StatelessWidget {
  const _NeutralShirt();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 102,
    height: 108,
    child: CustomPaint(painter: _ShirtPainter()),
  );
}

class _ShirtPainter extends CustomPainter {
  const _ShirtPainter();
  @override
  void paint(Canvas c, Size s) {
    final p = Path()
      ..moveTo(s.width * .27, 10)
      ..lineTo(8, 27)
      ..lineTo(0, 51)
      ..lineTo(21, 61)
      ..lineTo(25, 47)
      ..lineTo(25, s.height)
      ..lineTo(s.width - 25, s.height)
      ..lineTo(s.width - 25, 47)
      ..lineTo(s.width - 21, 61)
      ..lineTo(s.width, 51)
      ..lineTo(s.width - 8, 27)
      ..lineTo(s.width * .73, 10)
      ..quadraticBezierTo(s.width * .5, 29, s.width * .27, 10);
    c.drawPath(p, Paint()..color = const Color(0xffd9e6ff));
    c.drawLine(
      Offset(s.width / 2, 34),
      Offset(s.width / 2, s.height - 8),
      Paint()
        ..color = const Color(0xff9ab8ed)
        ..strokeWidth = 10,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: .09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(16, 12, s.width - 32, s.height - 20),
        const Radius.circular(12),
      ),
      p,
    );
    c.drawCircle(Offset(s.width / 2, s.height / 2), 30, p);
    c.drawLine(Offset(s.width / 2, 12), Offset(s.width / 2, s.height - 8), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StandingTile extends StatelessWidget {
  const StandingTile({
    super.key,
    required this.team,
    required this.selected,
    required this.onTap,
  });
  final TeamData team;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: selected ? const Color(0xffe0eaff) : Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                metric(team.rank),
                style: const TextStyle(
                  color: fantaBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TeamBadge(name: team.name, url: team.logo, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (team.owner.isNotEmpty)
                    Text(
                      team.owner,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xff61738b),
                      ),
                    ),
                  Text(
                    '${metric(team.played)} partite',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xff61738b),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  metric(team.points),
                  style: const TextStyle(
                    fontSize: 22,
                    color: fantaBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'PUNTI',
                  style: TextStyle(fontSize: 9, color: Color(0xff61738b)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class TeamTile extends StatelessWidget {
  const TeamTile({
    super.key,
    required this.team,
    required this.selected,
    required this.onTap,
  });
  final TeamData team;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: TeamBadge(name: team.name, url: team.logo),
      title: Text(
        team.name,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? fantaBlue : null,
        ),
      ),
      subtitle: team.owner.isEmpty ? null : Text(team.owner),
      trailing: team.credits == null
          ? const Icon(Icons.chevron_right_rounded)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metric(team.credits),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: fantaBlue,
                  ),
                ),
                const Text('CREDITI', style: TextStyle(fontSize: 9)),
              ],
            ),
      onTap: onTap,
    ),
  );
}

class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, this.highlight});
  final MatchData match;
  final String? highlight;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xffe1e7f2)),
    ),
    child: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xffdce7fc),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Text(
            match.round == null
                ? 'Giornata non indicata'
                : '${match.round}ª giornata',
            style: const TextStyle(
              color: Color(0xff244e98),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: _side(match.home, match.homeLogo)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  match.completed
                      ? '${match.homeScore} – ${match.awayScore}'
                      : 'VS',
                  style: TextStyle(
                    fontSize: match.completed ? 25 : 16,
                    fontWeight: FontWeight.w800,
                    color: match.completed
                        ? const Color(0xff153266)
                        : const Color(0xff8c9ab1),
                  ),
                ),
              ),
              Expanded(child: _side(match.away, match.awayLogo)),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _side(String name, String? logo) => Column(
    children: [
      TeamBadge(name: name, url: logo, size: 44),
      const SizedBox(height: 9),
      Text(
        name,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: name == highlight ? FontWeight.w800 : FontWeight.w500,
          color: name == highlight ? fantaBlue : const Color(0xff273b58),
        ),
      ),
    ],
  );
}

class PlayerTile extends StatelessWidget {
  const PlayerTile({super.key, required this.player});
  final PlayerData player;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: const Color(0xffe0eaff),
      child: Text(
        player.role,
        style: const TextStyle(fontSize: 11, color: fantaBlue),
      ),
    ),
    title: Text(
      player.name,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: player.club.isEmpty ? null : Text(player.club),
    trailing: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(metric(player.cost)),
        const Text('COSTO', style: TextStyle(fontSize: 9)),
      ],
    ),
  );
}
