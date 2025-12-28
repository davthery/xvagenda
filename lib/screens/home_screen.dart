import 'package:flutter/material.dart';
import 'package:calendar_view/calendar_view.dart';
import '../models/rugby_event.dart';
import '../services/google_sheets_service.dart';
import '../services/database_service.dart';
import '../utils/logger.dart';
import 'log_viewer_screen.dart';

// Enum pour les différentes vues du calendrier
enum CalendarViewType { month, week, day }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  final DatabaseService _dbService = DatabaseService();
  final EventController _eventController = EventController();
  final _logger = AppLogger();
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _currentDate = DateTime.now();
  final GlobalKey<MonthViewState> _monthViewKey = GlobalKey<MonthViewState>();
  final GlobalKey<WeekViewState> _weekViewKey = GlobalKey<WeekViewState>();
  final GlobalKey<DayViewState> _dayViewKey = GlobalKey<DayViewState>();
  bool _isOffline = false;
  CalendarViewType _currentView = CalendarViewType.month;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  } //ou la base de données

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isOffline = false;
    });

    try {
      _logger.info('🚀 Début du chargement des événements...');
      
      // Vide le contrôleur avant de recharger
      _eventController.removeWhere((event) => true);
      
      List<RugbyEvent> events = [];
      
      // Essaie d'abord de charger depuis Google Sheets
      try {
        _logger.info('🌐 Tentative de chargement depuis Google Sheets...');
        await _sheetsService.init();
        events = await _sheetsService.fetchEvents();
        _logger.success('✅ Événements chargés depuis Google Sheets');
      } catch (e) {
        // En cas d'erreur réseau, charge depuis la base de données locale
        _logger.warning('⚠️ Impossible de charger depuis Google Sheets: $e');
        _logger.info('📱 Chargement depuis la base de données locale...');
        events = await _dbService.getAllEvents();
        
        if (events.isNotEmpty) {
          _isOffline = true;
          _logger.success('✅ Événements chargés depuis la base de données locale');
        } else {
          throw Exception('Aucun événement disponible et impossible de se connecter à Google Sheets');
        }
      }
      //await _sheetsService.init();
      //events = await _sheetsService.fetchEvents();

      _logger.info('📅 Ajout des événements au calendrier: ${events.length} événements');
      
      // Ajoute chaque événement au contrôleur du calendrier
      for (var event in events) {
        _logger.debug('  → ${event.title}: ${event.startTime}');
        
        // Format du titre avec les heures
        final eventTitle = '${_formatTime(event.startTime)} - ${event.title}';
        
        _eventController.add(
          CalendarEventData(
            title: eventTitle,
            description: event.description,
            date: event.startTime,
            startTime: event.startTime,
            endTime: event.endTime,
            event: event, // Stocke l'objet complet pour y accéder plus tard
            color: _getEventColor(event.category),
          ),
        );
      }

      _logger.success('✅ Chargement terminé: ${events.length} événements ajoutés');
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _logger.error('❌ Erreur lors du chargement', error: e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des événements: $e';
      });
    }
  }

  // Callback appelé quand l'utilisateur change de mois par swipe
  void _onPageChange(DateTime date, int pageIndex) {
    setState(() {
      _currentDate = date;
    });
  }

  // Détermine la couleur selon la catégorie
  Color _getEventColor(String? category) {
    if (category == null) return Colors.blue;
    
    switch (category.toLowerCase()) {
      case 'Séniors':
        return Colors.black;
      case 'r5':
      case 'R5':
        return Colors.red;
      case 'match':
        return Colors.red;
      case 'entraînement':
      case 'entrainement':
        return Colors.green;
      case 'réunion':
      case 'reunion':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  // Méthodes de navigation pour les différentes vues
  void _goToToday() {
    setState(() {

      _currentDate = DateTime.now();
    });
    _monthViewKey.currentState?.jumpToMonth(_currentDate);
    _weekViewKey.currentState?.jumpToWeek(_currentDate);
    _dayViewKey.currentState?.jumpToDate(_currentDate);
  }

  void _goToPreviousPeriod() {
    setState(() {
      switch (_currentView) {
        case CalendarViewType.month:
          _currentDate = DateTime(_currentDate.year, _currentDate.month - 1);
          break;
        case CalendarViewType.week:
          _currentDate = _currentDate.subtract(const Duration(days: 7));
          break;
        case CalendarViewType.day:
          _currentDate = _currentDate.subtract(const Duration(days: 1));
          break;
      }
    });
    _monthViewKey.currentState?.jumpToMonth(_currentDate);
    _weekViewKey.currentState?.jumpToWeek(_currentDate);
    _dayViewKey.currentState?.jumpToDate(_currentDate);
  }

  void _goToNextPeriod() {
    setState(() {
      switch (_currentView) {
        case CalendarViewType.month:
          _currentDate = DateTime(_currentDate.year, _currentDate.month + 1);
          break;
        case CalendarViewType.week:
          _currentDate = _currentDate.add(const Duration(days: 7));
          break;
        case CalendarViewType.day:
          _currentDate = _currentDate.add(const Duration(days: 1));
          break;
      }
    });
    _monthViewKey.currentState?.jumpToMonth(_currentDate);
    _weekViewKey.currentState?.jumpToWeek(_currentDate);
    _dayViewKey.currentState?.jumpToDate(_currentDate);
  }

  void _changeView(CalendarViewType view) {
    setState(() {
      _currentView = view;
    });

     // Force le rechargement de la vue avec la date actuelle
/*     Future.delayed(const Duration(milliseconds: 100), () {
      switch (view) {
        case CalendarViewType.week:
          _logger.info('📅 Changement vers la vue semaine');
          _weekViewKey.currentState?.jumpToWeek(_currentDate);
          break;
        case CalendarViewType.day:
          _logger.info('📅 Changement vers la vue jour');
          _dayViewKey.currentState?.jumpToDate(_currentDate);
          break;
        case CalendarViewType.month:
          _logger.info('📅 Changement vers la vue mois');
          _monthViewKey.currentState?.jumpToMonth(_currentDate);
          break;
      }
    });  */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 28,
              width: 28,
            ),
            const SizedBox(width: 12),
            const Text('XV de l\'Erdre - Planning'),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 24, 24, 24),
        foregroundColor: Colors.white,
        actions: [
          if (_isOffline)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Tooltip(
                  message: 'Mode hors ligne - données en cache',
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        'Hors ligne',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.article),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LogViewerScreen(),
                ),
              );
            },
            tooltip: 'Voir les logs',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement des événements...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadEvents,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Barre de sélection des vues
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.blue[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SegmentedButton<CalendarViewType>(
                            segments: const [
                              ButtonSegment(
                                value: CalendarViewType.month,
                                label: Text('Mois'),
                                icon: Icon(Icons.calendar_month),
                              ),
                              ButtonSegment(
                                value: CalendarViewType.week,
                                label: Text('Semaine'),
                                icon: Icon(Icons.calendar_view_week),
                              ),
                              ButtonSegment(
                                value: CalendarViewType.day,
                                label: Text('Jour'),
                                icon: Icon(Icons.calendar_view_day),
                              ),
                            ],
                            selected: <CalendarViewType>{_currentView},
                            onSelectionChanged: (Set<CalendarViewType> newSelection) {
                              _changeView(newSelection.first);
                            },
                          ),
                        ],
                      ),
                    ),
                    // Barre de navigation du calendrier
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.green[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Bouton période précédente
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _goToPreviousPeriod,
                            tooltip: 'Période précédente',
                            color: Colors.green[800],
                          ),
                          // Affichage du titre et bouton aujourd'hui
                          Expanded(
                            child: InkWell(
                              onTap: _goToToday,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _getViewTitle(),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[800],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (!_isCurrentMonth(_currentDate))
                                      Text(
                                        'Appuyer pour aujourd\'hui',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Bouton période suivante
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _goToNextPeriod,
                            tooltip: 'Période suivante',
                            color: Colors.green[800],
                          ),
                        ],
                      ),
                    ),
                    // Calendrier - Afficher la vue actuelle
                    Expanded(
                      child: _currentView == CalendarViewType.month
                          ? MonthView(
                              key: _monthViewKey,
                              controller: _eventController,
                              minMonth: DateTime(2025),
                              maxMonth: DateTime(2027),
                              initialMonth: _currentDate,
                              cellAspectRatio: 0.7,
                              onPageChange: _onPageChange,
                              onEventTap: (event, date) {
                                _showEventDetails(context, event);
                              },
                              onCellTap: (events, date) {
                                if (events.isNotEmpty) {
                                  _showDayEvents(context, events, date);
                                }
                              },
                              headerBuilder: (date) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.green[300]!,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                                        .map((day) => Expanded(
                                              child: Center(
                                                child: Text(
                                                  day,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green[800],
                                                  ),
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                );
                              },
                            )
                          : _currentView == CalendarViewType.week
                              ? WeekView(
                                  key: _weekViewKey,
                                  controller: _eventController,
                                  minDay: DateTime(2025),
                                  maxDay: DateTime(2027),
                                  initialDay: _currentDate,
                                  onEventTap: (events, date) {
                                    if (events.isNotEmpty) {
                                      _showEventDetails(context, events.first);
                                    }
                                  },
                                  onDateLongPress: (date) {},
                                )
                              : DayView(
                                  key: _dayViewKey,
                                  controller: _eventController,
                                  minDay: DateTime(2025),
                                  maxDay: DateTime(2027),
                                  initialDay: _currentDate,
                                  onEventTap: (events, date) {
                                    if (events.isNotEmpty) {
                                      _showEventDetails(context, events.first);
                                    }
                                  },
                                  onDateLongPress: (date) {},
                                ),
                    ),
                  ],
                ),
    );
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _getViewTitle() {
    switch (_currentView) {
      case CalendarViewType.month:
        return _formatMonthYear(_currentDate);
      case CalendarViewType.week:
        final weekStart = _currentDate.subtract(Duration(days: _currentDate.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return '${weekStart.day} - ${weekEnd.day} ${_formatMonthYear(weekStart)}';
      case CalendarViewType.day:
        return '${_currentDate.day} ${_formatMonthYear(_currentDate)}';
    }
  }

  bool _isCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  void _showEventDetails(BuildContext context, CalendarEventData event) {
    final rugbyEvent = event.event as RugbyEvent;
    
    // Extraire le titre original sans les heures
    final originalTitle = event.title.contains(' - ') 
      ? event.title.split(' - ')[1] 
      : event.title;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(originalTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (rugbyEvent.category != null) ...[
                _buildDetailRow(Icons.category, 'Catégorie', rugbyEvent.category!),
                const SizedBox(height: 8),
              ],
              _buildDetailRow(
                Icons.calendar_today,
                'Début',
                _formatDateTime(event.startTime!),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.calendar_today,
                'Fin',
                _formatDateTime(event.endTime!),
              ),
              if (rugbyEvent.location != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow(Icons.location_on, 'Lieu', rugbyEvent.location!),
              ],
              if (event.description != null && event.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(event.description!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  void _showDayEvents(
    BuildContext context,
    List<CalendarEventData> events,
    DateTime date,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Événements du ${date.day}/${date.month}/${date.year}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  // Extraire le titre original sans les heures
                /*  final titleWithTime = event.title;
                  final originalTitle = titleWithTime.contains(' - ') 
                    ? titleWithTime.split(' - ', 1)[1] 
                    : titleWithTime;
                  */
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: event.color,
                        child: const Icon(Icons.event, color: Colors.white),
                      ),
//                      title: Text(originalTitle),
                      title: Text(event.title),
                      subtitle: Text(
                        '${_formatTime(event.startTime!)} - ${_formatTime(event.endTime!)}',
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showEventDetails(context, event);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} à ${_formatTime(dateTime)}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
