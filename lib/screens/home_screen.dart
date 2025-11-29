import 'package:flutter/material.dart';
import 'package:calendar_view/calendar_view.dart';
import '../models/rugby_event.dart';
import '../services/google_sheets_service.dart';
import '../utils/logger.dart';
import 'log_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  final EventController _eventController = EventController();
  final _logger = AppLogger();
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _currentMonth = DateTime.now();
  final GlobalKey<MonthViewState> _monthViewKey = GlobalKey<MonthViewState>();

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  // Charge les événements depuis Google Sheets
  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _logger.info('🚀 Début du chargement des événements...');
      
      // Vide le contrôleur avant de recharger
      _eventController.removeWhere((event) => true);
      
      // Initialise le service et récupère les événements
      await _sheetsService.init();
      final events = await _sheetsService.fetchEvents();

      _logger.info('📅 Ajout des événements au calendrier:');
      
      // Ajoute chaque événement au contrôleur du calendrier
      for (var event in events) {
        _logger.debug('  → ${event.title}: ${event.startTime}');
        
        _eventController.add(
          CalendarEventData(
            title: event.title,
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

  // Navigation vers le mois précédent
  void _goToPreviousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _monthViewKey.currentState?.jumpToMonth(_currentMonth);
  }

  // Navigation vers le mois suivant
  void _goToNextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _monthViewKey.currentState?.jumpToMonth(_currentMonth);
  }

  // Retour au mois actuel
  void _goToToday() {
    setState(() {
      _currentMonth = DateTime.now();
    });
    _monthViewKey.currentState?.jumpToMonth(_currentMonth);
  }

  // Callback appelé quand l'utilisateur change de mois par swipe
  void _onPageChange(DateTime date, int pageIndex) {
    setState(() {
      _currentMonth = date;
    });
  }

  // Détermine la couleur selon la catégorie
  Color _getEventColor(String? category) {
    if (category == null) return Colors.blue;
    
    switch (category.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('XV de l\'Erdre - Planning'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
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
                          // Bouton mois précédent
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _goToPreviousMonth,
                            tooltip: 'Mois précédent',
                            color: Colors.green[800],
                          ),
                          // Affichage du mois et année + bouton aujourd'hui
                          Expanded(
                            child: InkWell(
                              onTap: _goToToday,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatMonthYear(_currentMonth),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[800],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (!_isCurrentMonth(_currentMonth))
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
                          // Bouton mois suivant
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _goToNextMonth,
                            tooltip: 'Mois suivant',
                            color: Colors.green[800],
                          ),
                        ],
                      ),
                    ),
                    // Calendrier
                    Expanded(
                      child: MonthView(
                        key: _monthViewKey,
                        controller: _eventController,
                        minMonth: DateTime(2024),
                        maxMonth: DateTime(2026),
                        initialMonth: _currentMonth,
                        cellAspectRatio: 0.7,
                        onPageChange: _onPageChange,
                        onEventTap: (event, date) {
                          _showEventDetails(context, event);
                        },
                        onCellTap: (events, date) {
                          // Affiche les événements du jour sélectionné
                          if (events.isNotEmpty) {
                            _showDayEvents(context, events, date);
                          }
                        },
                        headerBuilder: (date) {
                          // En-tête des jours de la semaine
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

  bool _isCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  void _showEventDetails(BuildContext context, CalendarEventData event) {
    final rugbyEvent = event.event as RugbyEvent;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
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
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: event.color,
                        child: const Icon(Icons.event, color: Colors.white),
                      ),
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
