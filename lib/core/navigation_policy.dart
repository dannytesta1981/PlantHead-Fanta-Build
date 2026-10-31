enum LinkAction { web, external, block }

class NavigationPolicy {
  static final home = Uri.parse('https://leghe.fantacalcio.it/');
  static final login = Uri.parse('https://leghe.fantacalcio.it/login');
  static const officialHosts = {'leghe.fantacalcio.it'};
  static const identityHosts = {
    'accounts.google.com',
    'www.facebook.com',
    'm.facebook.com',
    'appleid.apple.com',
  };

  static bool isOfficial(Uri? uri) =>
      uri != null &&
      uri.scheme == 'https' &&
      officialHosts.contains(uri.host) &&
      (!uri.hasPort || uri.port == 443) &&
      uri.userInfo.isEmpty;

  static LinkAction classify(Uri? uri) {
    if (uri == null || uri.userInfo.isNotEmpty) return LinkAction.block;
    if (isOfficial(uri)) return LinkAction.web;
    if (uri.scheme == 'https' &&
        identityHosts.contains(uri.host) &&
        (!uri.hasPort || uri.port == 443)) {
      return LinkAction.web;
    }
    if ((uri.scheme == 'https' && uri.host.isNotEmpty) ||
        uri.scheme == 'mailto' ||
        uri.scheme == 'tel') {
      return LinkAction.external;
    }
    return LinkAction.block;
  }

  // Never retain authentication parameters, fragments, or history URLs on disk.
  static Uri? safeBrowserUri(Uri? uri) {
    if (!isOfficial(uri)) return null;
    return Uri(
      scheme: uri!.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    );
  }

  static String safeFilename(String? suggested) {
    final base = (suggested ?? 'documento').split(RegExp(r'[/\\]')).last;
    final clean = base.replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_');
    if (clean.isEmpty || clean == '.' || clean == '..') return 'documento';
    return clean.substring(0, clean.length > 100 ? 100 : clean.length);
  }
}

const sectionLabels = <String, List<String>>{
  'dashboard': ['Dashboard'],
  'rose': ['Rose', 'Squadre'],
  'calendario': ['Calendario'],
  'classifica': ['Classifica'],
  'menu': ['Menu', 'Menù'],
  'formazione': ['Inserisci formazione'],
  'risultati': ['Ultimi risultati'],
  'mercato': ['Mercato', 'Mercati'],
  'listone': ['Lista calciatori', 'Listone'],
  'svincolati': ['Svincolati'],
  'calcolo': ['Calcolo Giornata'],
  'gestione_rose': ['Gestione Rose'],
  'gestione_formazioni': ['Gestione Formazioni'],
  'profilo': ['Profilo', 'Profilo Lega'],
  'opzioni': ['Opzioni di Lega', 'Regolamento ed Opzioni'],
  'partecipanti': ['Partecipanti'],
  'competizioni': ['Competizioni'],
  'divisioni': ['Gestione Divisioni'],
  'trofei': ['Sala Trofei'],
  'registro': ['Registro Attività Admin'],
  'documenti': ['Documenti', 'Documenti di Lega'],
  'comunicazioni': ['Comunicazioni'],
  'logout': ['Logout', 'Esci'],
};
