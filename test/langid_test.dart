/// Spec 034 US3: the bundled n-gram detector — held-out sentences per
/// language (none are corpus lines), the accent-less Spanish cases that
/// motivated it, the low-confidence fallback into the rule table, and the
/// guards that keep non-Latin text away from the model.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/langid/langid.dart';
import 'package:klhu/language.dart';

void main() {
  // Held-out English — written for this test, not drawn from
  // tool/langid_corpus.
  const english = [
    'The library closes at nine o\'clock on weekdays.',
    'She forgot her umbrella on the train this morning.',
    'We should probably leave before the traffic gets worse.',
    'He asked whether anyone had seen his keys.',
    'The recipe calls for two cups of flour and a pinch of salt.',
    'They have been waiting for the bus for almost an hour.',
    'I cannot believe how fast the years go by.',
    'The museum opens its new exhibition next month.',
    'Please make sure the door is locked before you go.',
    'My brother plays the guitar in a band on weekends.',
    'The weather forecast says it will snow tomorrow.',
    'She writes in her journal every night before sleeping.',
    'We need to buy more milk, eggs and bread.',
    'The teacher explained the lesson very clearly.',
    'He works as a carpenter in the city center.',
    'The baby woke up crying in the middle of the night.',
    'I have never been to Australia before.',
    'The concert was cancelled because of the storm.',
    'She made a cake for her daughter\'s birthday.',
    'They moved into a new apartment last week.',
    'The road was closed due to the accident.',
    'He reads the newspaper with his morning coffee.',
    'We watched a movie together on Friday night.',
    'The children built a sandcastle at the beach.',
    'She studies medicine at the university.',
    'The store sells fresh fruit and vegetables.',
    'He forgot to set his alarm clock again.',
    'The flowers in the garden need water.',
    'We talked about our plans for the summer.',
    'The hotel room had a beautiful view of the sea.',
  ];

  // Held-out Spanish — accented and accent-less alike (the keyboard drops
  // accents, which is the bug this feature fixes).
  const spanish = [
    'Voy al mercado a comprar frutas y verduras.',
    'La reunion se cancelo por la tormenta.',
    'Mi hermano toca la guitarra en una banda.',
    'Tenemos que salir antes de que empeore el trafico.',
    'Ella olvido su paraguas en el tren.',
    'El museo abre una nueva exposicion el mes que viene.',
    'No puedo creer lo rapido que pasan los anos.',
    'La maestra explico la leccion muy claramente.',
    'El bebe se desperto llorando en la madrugada.',
    'Nunca he estado en Australia antes.',
    'Se mudaron a un apartamento nuevo la semana pasada.',
    'El camino estaba cerrado por el accidente.',
    'El lee el periodico con su cafe de la manana.',
    'Vimos una pelicula juntos el viernes por la noche.',
    'Los ninos construyeron un castillo de arena.',
    'Ella estudia medicina en la universidad.',
    'La tienda vende fruta fresca y verduras.',
    'El olvido poner su despertador otra vez.',
    'Las flores del jardin necesitan agua.',
    'Hablamos de nuestros planes para el verano.',
    'La habitacion del hotel tenia una vista preciosa.',
    'Que tiempo hace hoy en tu ciudad?',
    'Donde esta la estacion de metro mas cercana?',
    'Cuanto cuesta este vestido en la tienda?',
    'Cuando llega el proximo tren a Madrid?',
    'Por que no viniste a la fiesta de anoche?',
    'Como se dice gracias en aleman?',
    'Quien es esa persona que esta ahi afuera?',
    'Cual es tu color favorito y por que?',
    'Voy al cine esta noche con mis amigos.',
    'Nos vemos manana en la estacion.',
  ];

  // Held-out Simplified Chinese — the CJK rule answers these; they are here
  // so a regression that lets the model answer first is caught.
  const chinese = [
    '今天天气很好，我们去公园散步吧。',
    '他昨天在图书馆借了三本书。',
    '这家餐厅的菜很好吃，价格也不贵。',
    '我明天要早起去上班，不能睡懒觉。',
    '她正在学开车，已经练了一个月了。',
    '孩子们在院子里玩得很开心。',
    '这个问题很复杂，需要仔细考虑。',
    '我们周末打算去爬山，你去吗？',
    '手机没电了，我找不到充电器。',
    '医生说要多喝水，少吃油腻的食物。',
    '火车晚点了一个小时，请大家耐心等待。',
    '这部电影的故事很感人，看得我哭了。',
    '他每天早上六点起床跑步。',
    '超市今天有特价，牛奶打八折。',
    '我不太喜欢下雨天，路上很滑。',
    '她把生日礼物藏在了床底下。',
    '老师布置的作业太多了，写不完。',
    '我们公司下个月要搬到新办公室。',
    '这道菜太辣了，我吃不了。',
    '他在银行工作，负责贷款业务。',
    '春天来了，树上开满了花。',
    '飞机还有两个小时才起飞，我们再等一会儿。',
    '她的普通话说得非常标准。',
    '这个城市的冬天很冷，会下大雪。',
    '请把窗户打开，房间里太闷了。',
    '他忘了带钥匙，被锁在门外了。',
    '周末我想去看一场音乐会。',
    '孩子发烧了，我们赶紧去医院。',
    '这本书的作者是著名的作家。',
    '他们一家人去年搬到了上海。',
  ];

  group('detectWithModel on held-out sentences', () {
    test('English sentences resolve to en', () {
      var correct = 0;
      for (final s in english) {
        final r = detectWithModel(s);
        if (r.language == 'en') correct++;
      }
      expect(correct / english.length, greaterThanOrEqualTo(0.9),
          reason: 'en top-1 below SC-005 floor');
    });

    test('Spanish sentences — accented and accent-less — resolve to es', () {
      var correct = 0;
      for (final s in spanish) {
        final r = detectWithModel(s);
        if (r.language == 'es') correct++;
      }
      expect(correct / spanish.length, greaterThanOrEqualTo(0.9),
          reason: 'es top-1 below SC-005 floor');
    });

    test('accent-less Spanish the rule table misses still reads es', () {
      // No accent, no listed word — only the model can answer these.
      for (final s in const [
        'Voy al cine esta noche con mis amigos.',
        'Nos vemos manana en la estacion.',
        'El ano pasado viajamos a Espana.',
        'La cuenta por favor, gracias.',
        'Me gusta mucho la musica que escuchas.',
      ]) {
        expect(detectLanguage(s), 'es', reason: s);
      }
    });

    test('confidence is a 0..1 margin and real sentences clear the gate', () {
      for (final s in [...english.take(5), ...spanish.take(5)]) {
        final r = detectWithModel(s);
        expect(r.confidence, inInclusiveRange(0.0, 1.0));
        expect(r.confidence, greaterThanOrEqualTo(kLangIdThreshold),
            reason: '$s scored ${r.language} ${r.confidence}');
      }
    });
  });

  group('guards and fallback', () {
    test('non-Latin and symbol-only text carries no model evidence', () {
      for (final s in const [
        'こんにちは',
        'Привет мир',
        '12345 !!! ???',
        '   ',
      ]) {
        expect(detectWithModel(s).confidence, 0, reason: s);
      }
    });

    test('text under 8 chars defers to the rules', () {
      // 'Hola!' is below the model's minimum length; the Spanish-only word
      // list still answers it.
      expect(detectWithModel('Hola!').confidence, 0);
      expect(detectLanguage('Hola!'), 'es');
    });

    test('low-confidence Latin text falls back to the rule table', () {
      // English-looking but too short/ambiguous for the model; no Spanish
      // signal → the table's default.
      expect(detectLanguage('OK.'), 'en');
      expect(detectLanguage('the'), 'en');
    });

    test('CJK still wins before the model runs', () {
      var correct = 0;
      for (final s in chinese) {
        if (detectLanguage(s) == 'zh-Hans') correct++;
      }
      expect(correct / chinese.length, greaterThanOrEqualTo(0.98));
    });
  });
}
