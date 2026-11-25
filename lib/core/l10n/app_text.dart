import 'package:flutter/widgets.dart';

enum AppLanguage {
  russian(Locale('ru'), 'Рус', 'Русский'),
  kazakh(Locale('kk'), 'Қаз', 'Қазақша'),
  english(Locale('en'), 'EN', 'English');

  const AppLanguage(this.locale, this.shortLabel, this.label);

  final Locale locale;
  final String shortLabel;
  final String label;

  static AppLanguage fromCode(String? code) => switch (code) {
    'kk' => kazakh,
    'en' => english,
    _ => russian,
  };
}

enum AppText {
  language('Язык', 'Тіл', 'Language'),
  welcome('Добро пожаловать!', 'Қош келдіңіз!', 'Welcome!'),
  chooseRole(
    'Выберите, как продолжить',
    'Жалғастыру жолын таңдаңыз',
    'Choose how to continue',
  ),
  guest('Гость', 'Қонақ', 'Guest'),
  browseEvents('Просмотр мероприятий', 'Іс-шараларды қарау', 'Browse events'),
  administrator('Администратор', 'Әкімші', 'Administrator'),
  manageEvents(
    'Управление мероприятиями и билетами',
    'Іс-шаралар мен билеттерді басқару',
    'Manage events and tickets',
  ),
  back('Назад', 'Артқа', 'Back'),
  controllerSignIn('Вход контролёра', 'Бақылаушының кіруі', 'Controller login'),
  welcomeBack(
    'Рады вас видеть',
    'Сізді көргенімізге қуаныштымыз',
    'Welcome back',
  ),
  signInForEvents(
    'Войдите, чтобы увидеть назначенные события',
    'Өзіңізге бекітілген іс-шараларды көру үшін жүйеге кіріңіз',
    'Sign in to view your assigned events',
  ),
  email('Email', 'Электрондық пошта', 'Email'),
  enterEmail(
    'Введите email',
    'Электрондық пошта мекенжайын енгізіңіз',
    'Enter your email',
  ),
  password('Пароль', 'Құпиясөз', 'Password'),
  showPassword('Показать пароль', 'Құпиясөзді көрсету', 'Show password'),
  hidePassword('Скрыть пароль', 'Құпиясөзді жасыру', 'Hide password'),
  enterPassword(
    'Введите пароль',
    'Құпиясөзді енгізіңіз',
    'Enter your password',
  ),
  signIn('Войти', 'Кіру', 'Sign in'),
  signOut('Выйти', 'Шығу', 'Sign out'),
  events('Мероприятия', 'Іс-шаралар', 'Events'),
  attendees('Гости', 'Қонақтар', 'Guests'),
  retry('Повторить', 'Қайталау', 'Try again'),
  loadAssignedEvents(
    'Не удалось загрузить назначенные события',
    'Бекітілген іс-шараларды жүктеу мүмкін болмады',
    'Could not load your assigned events',
  ),
  noOfflineEvents(
    'Офлайн. Нет скачанных событий',
    'Офлайн. Жүктеп алынған іс-шаралар жоқ',
    'Offline. No downloaded events',
  ),
  noAssignedEvents(
    'Вас пока не назначили ни на одно событие',
    'Сізге әлі ешбір іс-шара бекітілмеген',
    'You have not been assigned any events yet',
  ),
  noVenue(
    'Площадка не указана',
    'Өтетін орын көрсетілмеген',
    'Venue not specified',
  ),
  eventAttendees('Гости события', 'Іс-шара қонақтары', 'Event guests'),
  recentEvent('Последнее мероприятие', 'Соңғы іс-шара', 'Most recent event'),
  recentEventScanner(
    'Сканер последнего мероприятия',
    'Соңғы іс-шараның сканері',
    'Scan tickets for the most recent event',
  ),
  recentEventAttendees(
    'Гости последнего мероприятия',
    'Соңғы іс-шараның қонақтары',
    'View guests for the most recent event',
  ),
  undoCheckIn('Отменить отметку', 'Белгіні алып тастау', 'Undo check-in'),
  confirmCheckIn('Отметить вход', 'Кіруді белгілеу', 'Check in'),
  undoQuestion(
    'Отменить отметку?',
    'Белгіні алып тастайсыз ба?',
    'Undo check-in?',
  ),
  checkInQuestion(
    'Отметить вход?',
    'Кіруді белгілейсіз бе?',
    'Check this guest in?',
  ),
  undoDetails(
    '{value} сможет снова пройти по этому билету.',
    '{value} осы билетпен қайта кіре алады.',
    '{value} can enter again with this ticket.',
  ),
  openEventScanner(
    'Открыть сканер события',
    'Іс-шара сканерін ашу',
    'Open event scanner',
  ),
  nameOrEmail('Имя или email', 'Аты немесе электрондық пошта', 'Name or email'),
  noAttendees(
    'На событии пока нет гостей',
    'Іс-шараның қонақтары әлі жоқ',
    'This event has no guests yet',
  ),
  attendeesNotFound(
    'Гости не найдены',
    'Қонақтар табылмады',
    'No guests found',
  ),
  registered('Зарегистрировано', 'Тіркелгендер', 'Registered'),
  checkedInCount('Отмечено', 'Кіргендер', 'Checked in'),
  saving('Сохраняем…', 'Сақталып жатыр…', 'Saving…'),
  ticketValid('Действителен', 'Жарамды', 'Valid'),
  ticketCheckedIn('Отмечен', 'Белгіленген', 'Checked in'),
  ticketCancelled('Отменён', 'Күші жойылған', 'Cancelled'),
  ticketRefunded('Возвращён', 'Қайтарылған', 'Refunded'),
  ticketUnknown('Неизвестный статус', 'Белгісіз күй', 'Unknown status'),
  scanAllowed('Вход разрешён', 'Кіруге рұқсат', 'Entry allowed'),
  scanUsed('Уже использован', 'Бұрын қолданылған', 'Already used'),
  scanInvalid('Недействителен', 'Жарамсыз', 'Invalid'),
  scanWrongEvent('Другое событие', 'Басқа іс-шара', 'Wrong event'),
  scanCampaign(
    'Это промо-код, не билет',
    'Бұл промокод, билет емес',
    'This is a promo code, not a ticket',
  ),
  scanCancelled('Билет отменён', 'Билеттің күші жойылған', 'Ticket cancelled'),
  scanRefunded('Билет возвращён', 'Билет қайтарылған', 'Ticket refunded'),
  scanEventCancelled(
    'Событие отменено',
    'Іс-шара тоқтатылған',
    'Event cancelled',
  ),
  offlineCheckedIn(
    'Отмечен (офлайн)',
    'Офлайн белгіленді',
    'Checked in offline',
  ),
  offlineAlreadyCheckedIn(
    'Уже отмечен',
    'Бұрын белгіленген',
    'Already checked in',
  ),
  scanningTickets(
    'Сканирование билетов',
    'Билеттерді сканерлеу',
    'Scan tickets',
  ),
  cameraUnavailable(
    'Сканирование камерой недоступно на этом устройстве.',
    'Бұл құрылғыда камерамен сканерлеу қолжетімсіз.',
    'Camera scanning is unavailable on this device.',
  ),
  backToScanner(
    'Нажмите, чтобы вернуться к сканеру',
    'Сканерге қайту үшін басыңыз',
    'Tap to return to the scanner',
  ),
  cameraDenied(
    'Нет доступа к камере. Разрешите доступ в настройках приложения и снова откройте сканер.',
    'Камераға кіруге рұқсат жоқ. Қолданба баптауларынан рұқсат беріп, сканерді қайта ашыңыз.',
    'Camera access is blocked. Allow camera access in Settings, then reopen the scanner.',
  ),
  cameraFailure(
    'Не удалось запустить камеру. Снова откройте сканер.',
    'Камераны іске қосу мүмкін болмады. Сканерді қайта ашыңыз.',
    'Could not start the camera. Reopen the scanner.',
  ),
  torchOff('Выключить фонарик', 'Шамды өшіру', 'Turn flashlight off'),
  torchOn('Включить фонарик', 'Шамды қосу', 'Turn flashlight on'),
  offline('Офлайн', 'Офлайн', 'Offline'),
  packDate(
    'Пакет от {value}',
    'Пакет уақыты: {value}',
    'Pack generated: {value}',
  ),
  packUnavailable('Пакет недоступен', 'Пакет қолжетімсіз', 'Pack unavailable'),
  unsent(
    'Не отправлено: {value}',
    'Жіберілмегені: {value}',
    'Not synced: {value}',
  ),
  packNotDownloaded(
    'Офлайн-пакет не скачан',
    'Офлайн пакет жүктеп алынбаған',
    'Offline pack not downloaded',
  ),
  downloading('Скачиваем…', 'Жүктеліп жатыр…', 'Downloading…'),
  updatePack('Обновить пакет', 'Пакетті жаңарту', 'Update pack'),
  downloadPack(
    'Скачать для офлайна',
    'Офлайн қолдану үшін жүктеп алу',
    'Download for offline use',
  ),
  syncing('Синхронизируем…', 'Синхрондалып жатыр…', 'Syncing…'),
  sync('Синхронизировать', 'Синхрондау', 'Sync'),
  conflicts('Конфликты', 'Қайшылықтар', 'Conflicts'),
  syncConflicts(
    'Конфликты синхронизации',
    'Синхрондау қайшылықтары',
    'Sync conflicts',
  ),
  loadConflictsFailure(
    'Не удалось загрузить конфликты',
    'Қайшылықтарды жүктеу мүмкін болмады',
    'Could not load conflicts',
  ),
  close('Закрыть', 'Жабу', 'Close'),
  checkInSourceOnline(
    'онлайн или вручную',
    'онлайн немесе қолмен',
    'online or manually',
  ),
  checkInSourceDevice(
    'на другом устройстве',
    'басқа құрылғыда',
    'on another device',
  ),
  sessionRestoreFailed(
    'Не удалось восстановить сохранённую сессию',
    'Сақталған сеансты қалпына келтіру мүмкін болмады',
    'Could not restore the saved session',
  ),
  malformedAuthResponse(
    'Сервер вернул некорректный ответ',
    'Сервер қате жауап қайтарды',
    'The server returned an invalid response',
  ),
  sessionSaveFailed(
    'Не удалось сохранить сессию на устройстве',
    'Сеансты құрылғыға сақтау мүмкін болмады',
    'Could not save your session on this device',
  ),
  sessionLogoutFailed(
    'Не удалось завершить сессию на устройстве',
    'Құрылғыдағы сеансты аяқтау мүмкін болмады',
    'Could not end the session on this device',
  ),
  credentialsInvalid(
    'Неверный email или пароль',
    'Электрондық пошта мекенжайы немесе құпиясөз қате',
    'Incorrect email or password',
  ),
  connectServerFailed(
    'Не удалось подключиться к серверу',
    'Серверге қосылу мүмкін болмады',
    'Could not connect to the server',
  ),
  loginFailed('Ошибка входа', 'Кіру қатесі', 'Login failed'),
  eventsFailed(
    'Не удалось загрузить мероприятия',
    'Іс-шараларды жүктеу мүмкін болмады',
    'Could not load events',
  ),
  eventsMalformed(
    'Сервер вернул некорректный список мероприятий',
    'Сервер іс-шаралардың қате тізімін қайтарды',
    'The server returned an invalid event list',
  ),
  eventNotFound(
    'Событие не найдено или нет доступа',
    'Іс-шара табылмады немесе кіруге рұқсат жоқ',
    'Event not found or access denied',
  ),
  serverUnreachableRetry(
    'Не удалось связаться с сервером. Попробуйте ещё раз.',
    'Сервермен байланысу мүмкін болмады. Қайта көріңіз.',
    'Could not reach the server. Try again.',
  ),
  ticketCheckFailed(
    'Не удалось проверить билет. Попробуйте ещё раз.',
    'Билетті тексеру мүмкін болмады. Қайта көріңіз.',
    'Could not verify the ticket. Try again.',
  ),
  unknownScanResult(
    'Сервер вернул неизвестный результат проверки',
    'Сервер белгісіз тексеру нәтижесін қайтарды',
    'The server returned an unknown scan result',
  ),
  attendeesFailed(
    'Не удалось загрузить гостей',
    'Қонақтар тізімін жүктеу мүмкін болмады',
    'Could not load guests',
  ),
  statsFailed(
    'Не удалось загрузить статистику',
    'Статистиканы жүктеу мүмкін болмады',
    'Could not load statistics',
  ),
  checkInFailed(
    'Не удалось отметить вход',
    'Кіруді белгілеу мүмкін болмады',
    'Could not check the guest in',
  ),
  ticketNotFound(
    'Билет не найден или нет доступа',
    'Билет табылмады немесе оған кіруге рұқсат жоқ',
    'Ticket not found or access denied',
  ),
  undoFailed(
    'Не удалось отменить отметку',
    'Белгіні алып тастау мүмкін болмады',
    'Could not undo check-in',
  ),
  serverUnreachable(
    'Не удалось связаться с сервером',
    'Сервермен байланысу мүмкін болмады',
    'Could not reach the server',
  ),
  malformedData(
    'Сервер вернул некорректные данные',
    'Сервер қате деректер қайтарды',
    'The server returned invalid data',
  ),
  signInToSync(
    'Войдите снова, чтобы продолжить синхронизацию',
    'Синхрондауды жалғастыру үшін қайта кіріңіз',
    'Sign in again to continue syncing',
  ),
  serverError(
    'Сервер вернул ошибку',
    'Сервер қате қайтарды',
    'The server returned an error',
  ),
  savePackFailed(
    'Не удалось сохранить офлайн-пакет',
    'Офлайн пакетті сақтау мүмкін болмады',
    'Could not save the offline pack',
  ),
  openPacksFailed(
    'Не удалось открыть офлайн-пакеты',
    'Офлайн пакеттерді ашу мүмкін болмады',
    'Could not open offline packs',
  ),
  signInAgain('Войдите снова', 'Қайта кіріңіз', 'Sign in again'),
  checkQueueFailed(
    'Не удалось проверить офлайн-очередь',
    'Офлайн кезекті тексеру мүмкін болмады',
    'Could not check the offline queue',
  ),
  needDownloadPack(
    'Офлайн-пакет недоступен. Скачайте его при подключении к сети.',
    'Офлайн пакет қолжетімсіз. Оны желіге қосылған кезде жүктеп алыңыз.',
    'The offline pack is unavailable. Download it when you are connected.',
  ),
  saveOfflineCheckInFailed(
    'Не удалось сохранить офлайн-отметку',
    'Офлайн белгіні сақтау мүмкін болмады',
    'Could not save the offline check-in',
  ),
  updateQueueFailed(
    'Не удалось обновить локальную очередь',
    'Жергілікті кезекті жаңарту мүмкін болмады',
    'Could not update the local queue',
  );

  const AppText(this.russian, this.kazakh, this.english);

  final String russian;
  final String kazakh;
  final String english;

  String inLanguage(AppLanguage language, [Object? value]) {
    final translation = switch (language) {
      AppLanguage.russian => russian,
      AppLanguage.kazakh => kazakh,
      AppLanguage.english => english,
    };
    return value == null
        ? translation
        : translation.replaceFirst('{value}', value.toString());
  }

  static final _byRussian = {for (final text in values) text.russian: text};

  static final _statusSuffix = RegExp(r'^(.*) (\((?:\d+|null)\))$');
}

extension TicketoffText on BuildContext {
  AppLanguage get language =>
      AppLanguage.fromCode(Localizations.localeOf(this).languageCode);

  String t(AppText text, [Object? value]) => text.inLanguage(language, value);

  // Repositories also surface server-provided details, which are displayed as sent.
  String localizedMessage(String message, {AppLanguage? forLanguage}) {
    final currentLanguage = forLanguage ?? language;
    if (currentLanguage == AppLanguage.russian) return message;
    if (AppText._byRussian[message] case final text?) {
      return text.inLanguage(currentLanguage);
    }
    final status = AppText._statusSuffix.firstMatch(message);
    if (status != null) {
      final text = AppText._byRussian[status[1]];
      if (text != null) {
        return '${text.inLanguage(currentLanguage)} ${status[2]}';
      }
    }
    return message;
  }
}
