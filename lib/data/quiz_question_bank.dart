class QuizQuestion {
  const QuizQuestion({
    required this.category,
    required this.prompt,
    required this.answers,
    required this.correctIndex,
    required this.explanation,
  });

  final String category;
  final String prompt;
  final List<String> answers;
  final int correctIndex;
  final String explanation;
}

QuizQuestion _buildQuestion(
  String category,
  String prompt,
  String correct,
  List<String> distractors,
  int seed,
  String explanation,
) {
  final unique = <String>[correct];
  for (final value in distractors) {
    if (value != correct && !unique.contains(value)) unique.add(value);
    if (unique.length == 4) break;
  }
  var fallback = 1;
  while (unique.length < 4) {
    final value = 'Opção $fallback';
    if (!unique.contains(value) && value != correct) unique.add(value);
    fallback++;
  }
  final correctPosition = seed % 4;
  final options = List<String>.filled(4, '');
  options[correctPosition] = correct;
  var next = 1;
  for (var i = 0; i < options.length; i++) {
    if (i == correctPosition) continue;
    options[i] = unique[next++];
  }
  return QuizQuestion(
    category: category,
    prompt: prompt,
    answers: List.unmodifiable(options),
    correctIndex: correctPosition,
    explanation: explanation,
  );
}

const List<List<String>> _capitals = [
  ['Moçambique', 'Maputo'], ['Angola', 'Luanda'], ['Zimbabwe', 'Harare'],
  ['Zâmbia', 'Lusaka'], ['Botswana', 'Gaborone'], ['Namíbia', 'Windhoek'],
  ['África do Sul (capital administrativa)', 'Pretória'], ['Tanzânia', 'Dodoma'],
  ['Quénia', 'Nairobi'], ['Etiópia', 'Adis Abeba'], ['Uganda', 'Campala'],
  ['Ruanda', 'Kigali'], ['Burundi', 'Gitega'], ['Madagáscar', 'Antananarivo'],
  ['Maurícia', 'Port Louis'], ['Gana', 'Acra'], ['Nigéria', 'Abuja'],
  ['Senegal', 'Dacar'], ['Egito', 'Cairo'], ['Marrocos', 'Rabat'],
  ['Tunísia', 'Tunes'], ['Argélia', 'Argel'], ['França', 'Paris'],
  ['Portugal', 'Lisboa'], ['Espanha', 'Madrid'], ['Itália', 'Roma'],
  ['Alemanha', 'Berlim'], ['Reino Unido', 'Londres'], ['Noruega', 'Oslo'],
  ['Suécia', 'Estocolmo'], ['Finlândia', 'Helsínquia'], ['Dinamarca', 'Copenhaga'],
  ['Islândia', 'Reiquiavique'], ['Polónia', 'Varsóvia'], ['Chéquia', 'Praga'],
  ['Áustria', 'Viena'], ['Grécia', 'Atenas'], ['Turquia', 'Ancara'],
  ['Japão', 'Tóquio'], ['China', 'Pequim'], ['Coreia do Sul', 'Seul'],
  ['Tailândia', 'Banguecoque'], ['Vietname', 'Hanói'], ['Filipinas', 'Manila'],
  ['Índia', 'Nova Deli'], ['Paquistão', 'Islamabad'], ['Nepal', 'Catmandu'],
  ['Bangladesh', 'Daca'], ['Austrália', 'Camberra'], ['Nova Zelândia', 'Wellington'],
  ['Canadá', 'Otava'], ['Estados Unidos', 'Washington, D.C.'],
  ['México', 'Cidade do México'], ['Brasil', 'Brasília'],
  ['Argentina', 'Buenos Aires'], ['Chile', 'Santiago'], ['Peru', 'Lima'],
  ['Colômbia', 'Bogotá'], ['Venezuela', 'Caracas'], ['Cuba', 'Havana'],
  ['Irlanda', 'Dublim'], ['Países Baixos', 'Amesterdão'], ['Suíça', 'Berna'],
  ['Croácia', 'Zagreb'], ['Sérvia', 'Belgrado'], ['Roménia', 'Bucareste'],
  ['Bulgária', 'Sófia'], ['Ucrânia', 'Quieve'], ['Rússia', 'Moscovo'],
];

List<QuizQuestion> buildQuizQuestionBank() {
  final questions = <QuizQuestion>[];

  // 121 multiplication questions.
  var seed = 0;
  for (var a = 2; a <= 12; a++) {
    for (var b = 2; b <= 12; b++) {
      final answer = a * b;
      questions.add(_buildQuestion(
        'Matemática',
        'Quanto é $a × $b?',
        '$answer',
        ['${answer + a}', '${answer - b}', '${answer + b + 3}', '${answer + a * 2}'],
        seed++,
        '$a multiplicado por $b é igual a $answer.',
      ));
    }
  }

  // 100 addition questions.
  for (var a = 0; a <= 9; a++) {
    for (var b = 0; b <= 9; b++) {
      final answer = a + b;
      questions.add(_buildQuestion(
        'Matemática',
        'Quanto é $a + $b?',
        '$answer',
        ['${answer + 1}', '${answer + 3}', '${answer > 0 ? answer - 1 : answer + 4}', '${answer + 5}'],
        seed++,
        'A soma de $a com $b é $answer.',
      ));
    }
  }

  final cityOptions = _capitals.map((entry) => entry[1]).toList();
  for (var i = 0; i < _capitals.length; i++) {
    final country = _capitals[i][0];
    final capital = _capitals[i][1];
    final wrong = <String>[];
    for (var step = 1; step < cityOptions.length && wrong.length < 3; step++) {
      final candidate = cityOptions[(i + step * 7) % cityOptions.length];
      if (candidate != capital && !wrong.contains(candidate)) wrong.add(candidate);
    }
    questions.add(_buildQuestion(
      'Geografia',
      'Qual é a capital de $country?',
      capital,
      wrong,
      seed++,
      '$capital é a capital de $country.',
    ));
  }

  const facts = <List<String>>[
    ['Natureza','Que animal é um mamífero que põe ovos?','Ornitorrinco','Golfinho|Leão|Cavalo','O ornitorrinco é um mamífero monotremo.'],
    ['Natureza','Quantas patas tem normalmente um insecto?','Seis','Oito|Dez|Quatro','Os insectos adultos têm três pares de patas.'],
    ['Natureza','Que animal é conhecido por ter três corações?','Polvo','Tubarão|Golfinho|Cavalo','O polvo tem três corações.'],
    ['Natureza','Qual é o maior animal conhecido do planeta?','Baleia-azul','Elefante-africano|Tubarão-branco|Girafa','A baleia-azul é o maior animal conhecido.'],
    ['Natureza','Qual destes animais é uma ave que não voa?','Pinguim','Águia|Andorinha|Morcego','Os pinguins são aves adaptadas à natação.'],
    ['Natureza','Como se chama o processo pelo qual as plantas usam luz para produzir alimento?','Fotossíntese','Fermentação|Respiração animal|Evaporação','Na fotossíntese, as plantas usam energia luminosa.'],
    ['Natureza','Qual é o maior mamífero terrestre actual?','Elefante-africano','Rinoceronte|Hipopótamo|Girafa','O elefante-africano é o maior mamífero terrestre actual.'],
    ['Natureza','Que parte da planta absorve normalmente água do solo?','Raiz','Flor|Fruto|Folha','As raízes absorvem água e sais minerais.'],
    ['Natureza','Qual destes animais é um anfíbio?','Rã','Lagarto|Pombo|Gato','As rãs são anfíbios e passam por metamorfose.'],
    ['Natureza','Em que habitat vivem naturalmente os camelos-dromedários?','Desertos','Recifes de coral|Florestas polares|Pântanos tropicais','Os dromedários estão adaptados a regiões áridas.'],
    ['Natureza','Qual é o nome da camada gasosa que envolve a Terra?','Atmosfera','Hidrosfera|Litosfera|Biosfera','A atmosfera é a camada de gases à volta da Terra.'],
    ['Natureza','Qual destes animais é um réptil?','Crocodilo','Sapo|Baleia|Águia','Os crocodilos são répteis.'],
    ['Natureza','Qual é o maior oceano da Terra?','Oceano Pacífico','Oceano Atlântico|Oceano Índico|Oceano Ártico','O Pacífico é o maior oceano.'],
    ['Natureza','Que gás é libertado pelas plantas durante a fotossíntese?','Oxigénio','Hélio|Azoto|Metano','A fotossíntese liberta oxigénio.'],
    ['Natureza','Qual destes animais é um marsupial?','Canguru','Leão|Girafa|Lobo','Os cangurus são marsupiais.'],
    ['Natureza','Como se chama a transformação de lagarta em borboleta?','Metamorfose','Germinação|Polinização|Mimetismo','A borboleta passa por metamorfose completa.'],
    ['Natureza','Que estrela fornece a maior parte da energia à Terra?','Sol','Sírius|Vega|Estrela Polar','O Sol é a estrela do nosso sistema planetário.'],
    ['Natureza','Que órgão os peixes usam principalmente para respirar na água?','Brânquias','Pulmões|Pele seca|Traqueias','As brânquias retiram oxigénio dissolvido na água.'],
    ['Natureza','Qual destes seres vivos é um fungo?','Cogumelo','Musgo|Samambaia|Alga verde','Os cogumelos pertencem ao reino dos fungos.'],
    ['Natureza','Que animal é famoso por mudar de cor para comunicar e camuflar-se?','Camaleão','Zebra|Pinguim|Girafa','Os camaleões conseguem alterar a coloração da pele.'],

    ['Ciência','Qual é a fórmula química da água?','H₂O','CO₂|O₂|NaCl','Uma molécula de água tem dois átomos de hidrogénio e um de oxigénio.'],
    ['Ciência','Qual é o símbolo químico do ouro?','Au','Ag|O|Fe','Au vem do nome latino aurum.'],
    ['Ciência','Qual é o símbolo químico do oxigénio?','O','Ox|Og|X','O símbolo químico do oxigénio é O.'],
    ['Ciência','A que temperatura a água pura congela ao nível do mar?','0 °C','10 °C|50 °C|100 °C','A água pura congela a 0 °C sob pressão atmosférica normal.'],
    ['Ciência','A que temperatura a água pura ferve ao nível do mar?','100 °C','50 °C|80 °C|120 °C','A água pura ferve a 100 °C sob pressão atmosférica normal.'],
    ['Ciência','Que planeta é conhecido como Planeta Vermelho?','Marte','Vénus|Júpiter|Saturno','O óxido de ferro dá a Marte a sua aparência avermelhada.'],
    ['Ciência','Qual é o maior planeta do Sistema Solar?','Júpiter','Terra|Marte|Mercúrio','Júpiter é o maior planeta do Sistema Solar.'],
    ['Ciência','Qual é o planeta mais próximo do Sol?','Mercúrio','Vénus|Terra|Marte','Mercúrio é o planeta mais próximo do Sol.'],
    ['Ciência','Qual é o satélite natural da Terra?','Lua','Fobos|Europa|Titã','A Lua é o satélite natural da Terra.'],
    ['Ciência','Que instrumento mede a temperatura?','Termómetro','Barómetro|Bússola|Régua','O termómetro mede a temperatura.'],
    ['Ciência','Que força nos mantém junto à superfície da Terra?','Gravidade','Magnetismo|Atrito do ar|Electricidade','A gravidade atrai os corpos para o centro da Terra.'],
    ['Ciência','Que unidade é usada para medir a corrente eléctrica?','Ampere','Watt|Volt|Metro','A corrente eléctrica mede-se em amperes.'],
    ['Ciência','Que unidade mede a força no Sistema Internacional?','Newton','Joule|Watt|Pascal','A força mede-se em newtons.'],
    ['Ciência','Qual é a partícula com carga eléctrica negativa?','Electrão','Protão|Neutrão|Fotão','O electrão tem carga negativa.'],
    ['Ciência','Qual é a partícula do núcleo atómico com carga positiva?','Protão','Electrão|Neutrão|Fotão','O protão tem carga positiva.'],
    ['Ciência','Qual é a velocidade aproximada da luz no vácuo?','300 mil km/s','30 mil km/s|3 mil km/s|3 milhões km/s','A luz viaja a cerca de 300 mil quilómetros por segundo.'],
    ['Ciência','Que órgão bombeia o sangue no corpo humano?','Coração','Pulmão|Estômago|Rim','O coração bombeia o sangue pelo sistema circulatório.'],
    ['Ciência','Que gás é mais abundante na atmosfera terrestre?','Azoto','Oxigénio|Dióxido de carbono|Hidrogénio','O azoto representa cerca de 78% da atmosfera.'],
    ['Ciência','Qual é o pH aproximado de uma solução neutra a 25 °C?','7','1|5|14','Uma solução neutra tem pH 7 a 25 °C.'],
    ['Ciência','Qual é a ciência que estuda os seres vivos?','Biologia','Geologia|Astronomia|Física','A biologia estuda a vida e os organismos.'],

    ['Tecnologia','Que sistema de numeração usa apenas 0 e 1?','Binário','Decimal|Romano|Hexadecimal','O sistema binário usa os dígitos 0 e 1.'],
    ['Tecnologia','O que significa a sigla CPU?','Unidade Central de Processamento','Unidade de Protecção de Código|Controlo de Potência Universal|Central de Programas Úteis','CPU significa Central Processing Unit.'],
    ['Tecnologia','Para que serve principalmente a memória RAM?','Guardar temporariamente dados em uso','Guardar fotografias para sempre|Carregar a bateria|Ligar o ecrã','A RAM guarda dados temporários usados pelos programas.'],
    ['Tecnologia','Que linguagem é usada para estruturar páginas Web?','HTML','SQL|Bash|Dart','HTML descreve a estrutura do conteúdo de páginas Web.'],
    ['Tecnologia','Qual destes é um navegador de Internet?','Firefox','Bluetooth|Android Studio|USB','Firefox é um navegador Web.'],
    ['Tecnologia','Que componente apresenta imagens no ecrã?','Ecrã','Microfone|Bateria|Antena GPS','O ecrã apresenta informação visual.'],
    ['Tecnologia','O que é uma palavra-passe forte?','Uma palavra-passe longa e difícil de adivinhar','O primeiro nome do utilizador|123456|A data de nascimento','Uma palavra-passe longa e única é mais difícil de adivinhar.'],
    ['Tecnologia','Qual é a função principal de um sistema operativo?','Gerir o dispositivo e os seus recursos','Criar electricidade|Aumentar o tamanho do ecrã|Substituir a Internet','O sistema operativo gere hardware e aplicações.'],
    ['Tecnologia','Que tecnologia permite ligar dispositivos sem fios a curta distância?','Bluetooth','HDMI|Ethernet|VGA','Bluetooth permite ligações sem fios a curta distância.'],
    ['Tecnologia','O que significa fazer uma cópia de segurança?','Guardar uma cópia dos dados para recuperação','Apagar todos os ficheiros|Aumentar o brilho|Desligar o Wi-Fi','Uma cópia de segurança ajuda a recuperar dados perdidos.'],
    ['Tecnologia','Qual destas unidades representa normalmente mais dados?','Gigabyte','Byte|Kilobyte|Bit','Um gigabyte representa muito mais dados do que um byte.'],
    ['Tecnologia','Para que serve o GPS?','Determinar a localização','Editar fotografias|Aumentar o volume|Traduzir textos sem dados','O GPS usa sinais de satélites para calcular a posição.'],
    ['Tecnologia','Qual destes é um formato comum de imagem?','PNG','MP3|MP4|TXT','PNG é um formato de imagem.'],
    ['Tecnologia','Qual destes é um formato comum de áudio?','MP3','PNG|CSV|HTML','MP3 é um formato de áudio comprimido.'],
    ['Tecnologia','Que prática ajuda a evitar aplicações maliciosas?','Instalar aplicações de fontes confiáveis','Abrir qualquer anexo|Partilhar palavras-passe|Ignorar actualizações','Fontes confiáveis e actualizações reduzem riscos.'],
    ['Tecnologia','O que é uma aplicação móvel?','Um programa criado para dispositivos móveis','Um cabo de carregamento|Uma rede social física|Um tipo de bateria','Uma aplicação móvel é software executado num telefone ou tablet.'],
    ['Tecnologia','O que significa URL?','Localizador uniforme de recursos','Unidade de Rede Local|Utilizador Registado Livre|Universal Radio Link','URL significa Uniform Resource Locator.'],
    ['Tecnologia','Qual destes é um serviço de armazenamento na nuvem?','Google Drive','Calculadora|Bluetooth|Lanterna','O armazenamento na nuvem guarda ficheiros em servidores remotos.'],
    ['Tecnologia','Qual é a finalidade de uma actualização de segurança?','Corrigir vulnerabilidades','Eliminar o teclado|Desligar a câmara|Reduzir a memória','Actualizações de segurança corrigem falhas conhecidas.'],
    ['Tecnologia','Que dispositivo converte som em sinal para gravação?','Microfone','Altifalante|Monitor|Rato','O microfone capta som e transforma-o em sinal.'],

    ['Cultura','Quantas vogais existem no alfabeto português?','Cinco','Quatro|Seis|Sete','As vogais são A, E, I, O e U.'],
    ['Cultura','Que sinal usamos normalmente no fim de uma pergunta directa?','Ponto de interrogação','Ponto final|Vírgula|Dois-pontos','O ponto de interrogação marca perguntas directas.'],
    ['Cultura','Como se chama uma palavra que tem significado oposto a outra?','Antónimo','Sinónimo|Homónimo|Verbo','Antónimo é uma palavra de sentido contrário.'],
    ['Cultura','Como se chama uma palavra com significado semelhante a outra?','Sinónimo','Antónimo|Pronome|Advérbio','Sinónimo é uma palavra de significado semelhante.'],
    ['Cultura','Quantos lados tem um triângulo?','Três','Quatro|Cinco|Seis','Um triângulo tem três lados.'],
    ['Cultura','Quantos lados tem um hexágono?','Seis','Cinco|Sete|Oito','Hexa significa seis.'],
    ['Cultura','Que instrumento tem normalmente teclas brancas e pretas?','Piano','Tambor|Flauta|Violino','O piano é um instrumento de teclado.'],
    ['Cultura','Em que cidade fica o Museu do Louvre?','Paris','Roma|Madrid|Lisboa','O Museu do Louvre fica em Paris.'],
    ['Cultura','Em que país se encontram as pirâmides de Gizé?','Egipto','México|Índia|Grécia','As pirâmides de Gizé ficam no Egipto.'],
    ['Cultura','Em que país nasceu o escritor Mia Couto?','Moçambique','Angola|Brasil|Portugal','Mia Couto nasceu na Beira, em Moçambique.'],
    ['Cultura','Qual é a moeda oficial do Japão?','Iene','Euro|Dólar|Libra','A moeda japonesa é o iene.'],
    ['Cultura','Quantos minutos tem uma hora?','60','30|90|100','Uma hora tem 60 minutos.'],
    ['Cultura','Quantos dias tem uma semana?','Sete','Cinco|Seis|Oito','Uma semana tem sete dias.'],
    ['Cultura','Qual é o idioma oficial do Brasil?','Português','Espanhol|Inglês|Francês','O português é o idioma oficial do Brasil.'],
    ['Cultura','Que continente inclui Moçambique?','África','Europa|Ásia|América do Sul','Moçambique fica no sudeste de África.'],
    ['Cultura','Qual é a cor que resulta da mistura de azul e amarelo na pintura tradicional?','Verde','Roxo|Laranja|Castanho','Na mistura tradicional de pigmentos, azul e amarelo produzem verde.'],
    ['Cultura','Que desporto utiliza uma bola e uma baliza em cada extremidade do campo?','Futebol','Natação|Atletismo|Xadrez','No futebol, os jogadores tentam marcar golos nas balizas.'],
    ['Cultura','Quantas notas existem na escala musical diatónica básica?','Sete','Cinco|Oito|Dez','A escala diatónica básica tem sete notas.'],
    ['Cultura','Qual é o nome da festa que marca a passagem de um ano para o outro?','Ano Novo','Páscoa|Carnaval|Dia do Trabalhador','O Ano Novo celebra o início de um novo ano.'],
    ['Cultura','Em que continente fica o Japão?','Ásia','África|Europa|Oceânia','O Japão é um país insular da Ásia Oriental.'],
    ['Desporto','Quantos jogadores de cada equipa estão normalmente em campo no basquetebol?','Cinco','Quatro|Seis|Sete','No basquetebol, cada equipa joga normalmente com cinco jogadores em campo.'],
    ['Desporto','Quantos jogadores de cada equipa estão normalmente em campo no voleibol?','Seis','Cinco|Sete|Oito','O voleibol de pavilhão é jogado por seis jogadores de cada lado.'],
    ['Desporto','Qual é a distância oficial de uma maratona?','42,195 km','40 km|45 km|50 km','A distância oficial da maratona é 42,195 quilómetros.'],
    ['Desporto','Quantos anéis tem o símbolo olímpico?','Cinco','Quatro|Seis|Sete','O símbolo olímpico é composto por cinco anéis entrelaçados.'],
    ['Desporto','Que cartão normalmente significa expulsão no futebol?','Vermelho','Amarelo|Azul|Verde','O cartão vermelho significa expulsão do jogador.'],
    ['Desporto','Como se chama o objecto usado para jogar badminton?','Volante','Disco|Bola oval|Bastão','O badminton é jogado com um volante, também chamado peteca.'],
    ['Desporto','Em que desporto se usa uma prancha para deslizar nas ondas?','Surf','Esgrima|Rugby|Ginástica','O surf consiste em deslizar sobre as ondas numa prancha.'],
    ['Desporto','Qual é o objectivo principal do xadrez?','Dar xeque-mate ao rei','Capturar todas as peças|Chegar ao fim do tabuleiro|Fazer uma linha de quatro','O xeque-mate acontece quando o rei está ameaçado e não pode escapar.'],
    ['Desporto','Quantos jogadores de cada equipa estão em campo no rugby union?','15','7|11|13','O rugby union é jogado por equipas de quinze jogadores.'],
    ['Desporto','Que país é frequentemente associado à origem do judo?','Japão','Brasil|França|Egipto','O judo foi desenvolvido no Japão no final do século XIX.'],
    ['Desporto','Que modalidade utiliza um taco e uma bola pequena em buracos?','Golfe','Ténis|Hóquei|Críquete','No golfe, o objectivo é colocar a bola no buraco com o menor número de tacadas.'],
    ['Desporto','Em que modalidade se disputa o Tour de France?','Ciclismo','Atletismo|Natação|Automobilismo','O Tour de France é uma famosa competição de ciclismo em estrada.'],
    ['Desporto','Que modalidade utiliza luvas e um ringue?','Boxe','Voleibol|Futebol|Badminton','O boxe é um desporto de combate praticado num ringue.'],
    ['Desporto','Qual é a função principal do guarda-redes no futebol?','Defender a baliza','Marcar apenas cantos|Arbitrar o jogo|Fazer lançamentos laterais','O guarda-redes protege a baliza e pode usar as mãos dentro da sua área, segundo as regras.'],
    ['Desporto','Quantos pontos vale normalmente um lançamento atrás da linha de três pontos no basquetebol?','Três','Um|Dois|Quatro','Um lançamento convertido de trás da linha de três vale três pontos.'],
    ['Desporto','Que modalidade combina corrida, ciclismo e natação?','Triatlo','Pentatlo|Decatlo|Maratona','O triatlo combina natação, ciclismo e corrida.'],
    ['Desporto','Em que desporto se usa uma bola oval e se podem marcar ensaios?','Rugby','Ténis|Golfe|Hóquei','No rugby, as equipas podem marcar pontos através de ensaios.'],
    ['Desporto','Quantos jogadores de cada equipa estão normalmente em campo no andebol?','Sete','Cinco|Seis|Oito','No andebol, jogam sete por equipa, incluindo o guarda-redes.'],
    ['Desporto','Qual destes é um estilo de natação?','Mariposa','Salto|Corrida|Remo','Mariposa é um dos estilos competitivos de natação.'],
    ['Desporto','Que desporto usa uma rede e raquetes para trocar uma bola?','Ténis','Atletismo|Boxe|Ciclismo','No ténis, os jogadores usam raquetes para passar a bola por cima da rede.'],
    ['Desporto','Qual é a distância de uma volta completa numa pista de atletismo padrão ao ar livre?','400 metros','100 metros|200 metros|800 metros','Uma pista de atletismo padrão tem 400 metros por volta na raia interior.'],
    ['Desporto','Que modalidade automobilística utiliza monolugares e grandes prémios?','Fórmula 1','Rali Dakar|Karting escolar|Motocross','A Fórmula 1 é uma categoria de corridas de automóveis monolugares.'],
    ['Desporto','Em que desporto se utiliza uma espada, florete ou sabre?','Esgrima','Ginástica|Judo|Taekwondo','A esgrima é um desporto de combate com armas próprias.'],
    ['Desporto','Que país é conhecido por ter criado o taekwondo?','Coreia','Canadá|Portugal|Quénia','O taekwondo desenvolveu-se na Coreia.'],
    ['Desporto','Qual destas provas é uma corrida de velocidade no atletismo?','100 metros','Maratona|Marcha de 50 km|Salto em altura','Os 100 metros são uma das provas clássicas de velocidade.'],
    ['Entretenimento','Como se chama a arte japonesa de dobrar papel?','Origami','Caligrafia|Ikebana|Haiku','Origami é a arte japonesa de dobrar papel.'],
    ['Entretenimento','Como se chamam as bandas desenhadas japonesas?','Manga','Anime|Origami|Kabuki','Manga é o nome dado às bandas desenhadas japonesas.'],
    ['Entretenimento','Como se chama uma história contada através de imagens em movimento?','Filme','Cartaz|Retrato|Mapa','Um filme apresenta imagens em movimento, normalmente com som.'],
    ['Entretenimento','Que prémio é conhecido por distinguir realizações no cinema?','Óscar','Grammy|Pulitzer|Nobel','Os Óscares distinguem realizações na indústria cinematográfica.'],
    ['Entretenimento','Qual destes instrumentos tem normalmente seis cordas?','Guitarra','Violino|Flauta|Tambor','A guitarra acústica ou eléctrica comum tem normalmente seis cordas.'],
    ['Entretenimento','Quantas cordas tem normalmente um violino?','Quatro','Três|Cinco|Seis','O violino tradicional tem quatro cordas.'],
    ['Entretenimento','Que instrumento pertence à família da percussão?','Tambor','Flauta|Harpa|Clarinete','O tambor produz som através de uma membrana percutida.'],
    ['Entretenimento','Como se chama uma peça escrita para ser representada por actores num palco?','Peça de teatro','Notícia|Receita|Manual','Uma peça de teatro é escrita para representação ao vivo.'],
    ['Entretenimento','Qual é o trabalho principal de um realizador de cinema?','Orientar a criação do filme','Vender bilhetes|Construir câmaras|Compor todas as músicas','O realizador coordena as escolhas artísticas e narrativas do filme.'],
    ['Entretenimento','Como se chama a técnica de animação que fotografa objectos parados em pequenos movimentos?','Stop motion','Fotografia panorâmica|Edição de texto|Transmissão ao vivo','Stop motion cria movimento juntando imagens de objectos ligeiramente deslocados.'],
    ['Entretenimento','Que género de filme procura provocar riso?','Comédia','Terror|Documentário|Suspense','A comédia procura divertir através do humor.'],
    ['Entretenimento','Que género de filme apresenta acontecimentos reais ou informação factual?','Documentário','Fantasia|Musical|Ficção científica','Um documentário procura apresentar pessoas, acontecimentos ou temas reais.'],
    ['Entretenimento','Como se chama a pessoa que mistura músicas numa festa ou actuação?','DJ','Actor|Cenógrafo|Dramaturgo','Um DJ selecciona e mistura faixas musicais.'],
    ['Entretenimento','Que género musical é frequentemente associado a uma actuação com cantores e orquestra no palco?','Ópera','Rap|Reggae|Fado','A ópera combina canto, música orquestral e representação teatral.'],
    ['Entretenimento','Como se chama uma sequência de versos organizada em grupos num poema?','Estrofe','Capítulo|Parágrafo|Refrão instrumental','Uma estrofe é um conjunto de versos de um poema.'],
    ['Entretenimento','Que profissional interpreta uma personagem numa peça ou filme?','Actor','Editor de som|Cameraman|Produtor executivo','O actor interpreta uma personagem.'],
    ['Entretenimento','Como se chama a arte de criar imagens com uma câmara?','Fotografia','Escultura|Cerâmica|Arquitectura','A fotografia regista imagens usando luz e uma câmara.'],
    ['Entretenimento','Qual é o nome de uma apresentação musical feita ao vivo perante público?','Concerto','Exposição|Leilão|Conferência','Um concerto é uma actuação musical diante de um público.'],
    ['Entretenimento','Que tipo de história inclui mundos imaginários e elementos mágicos?','Fantasia','Documentário|Biografia|Noticiário','A fantasia usa mundos e elementos imaginários, muitas vezes mágicos.'],
    ['Entretenimento','Como se chama a banda sonora de um filme?','Trilha sonora','Legenda|Guião de câmara|Cartaz','A banda sonora é a música e o áudio que acompanham o filme.'],
    ['Entretenimento','Que actividade consiste em cantar ao som de uma gravação com a letra no ecrã?','Karaoke','Origami|Escultura|Pintura','No karaoke, as pessoas cantam acompanhando uma gravação e a letra.'],
    ['Entretenimento','Como se chama a pessoa responsável por desenhar cenários para uma peça?','Cenógrafo','Árbitro|Locutor|Coreógrafo','O cenógrafo planeia e cria o espaço visual da representação.'],
    ['Entretenimento','Que arte usa movimentos do corpo ao ritmo da música?','Dança','Fotografia|Pintura|Cerâmica','A dança utiliza movimentos do corpo, muitas vezes acompanhados por música.'],
    ['Entretenimento','Qual destes é um género de videojogo focado em resolver desafios e enigmas?','Puzzle','Corrida|Desporto real|Simulador de voo apenas','Jogos puzzle destacam desafios de lógica e resolução de problemas.'],
    ['Entretenimento','Como se chama uma curta animação desenhada com personagens?','Desenho animado','Documentário|Telejornal|Podcast','Um desenho animado usa imagens desenhadas ou digitais para criar movimento.']
  ];

  const moreFacts = <List<String>>[
    ['Matemática','Quanto é 12 ao quadrado?','144','124|122|164','144 é a resposta correcta.'],
    ['Matemática','Quantos graus somam os ângulos internos de um triângulo?','180°','90°|270°|360°','180° é a resposta correcta.'],
    ['Matemática','Qual é a área de um quadrado com lado de 5 cm?','25 cm²','10 cm²|20 cm²|30 cm²','25 cm² é a resposta correcta.'],
    ['Matemática','Que fracção equivale a 25 por cento?','1/4','1/2|1/3|3/4','1/4 é a resposta correcta.'],
    ['Matemática','Qual é o primeiro número primo depois de 10?','11','12|13|15','11 é a resposta correcta.'],
    ['Matemática','Quanto é 7 vezes 8?','56','54|48|64','56 é a resposta correcta.'],
    ['Matemática','Quantos centímetros existem em 1 metro?','100','10|1000|10000','100 é a resposta correcta.'],
    ['Matemática','Qual é o perímetro de um quadrado com lado de 4 cm?','16 cm','8 cm|12 cm|20 cm','16 cm é a resposta correcta.'],
    ['Matemática','Quanto representa 3/4 em percentagem?','75%','25%|50%|80%','75% é a resposta correcta.'],
    ['Matemática','Qual é a raiz quadrada de 81?','9','8|7|10','9 é a resposta correcta.'],
    ['Matemática','Quantos lados tem um octógono?','Oito','Seis|Sete|Nove','Oito é a resposta correcta.'],
    ['Matemática','Quanto é 144 dividido por 12?','12','10|11|14','12 é a resposta correcta.'],
    ['Matemática','Que nome recebe um ângulo de 90 graus?','Ângulo recto','Ângulo raso|Ângulo agudo|Ângulo completo','Ângulo recto é a resposta correcta.'],
    ['Matemática','Qual é o valor de 2 elevado a 5?','32','16|24|64','32 é a resposta correcta.'],
    ['Matemática','Quantos minutos existem em duas horas e meia?','150','120|130|180','150 é a resposta correcta.'],
    ['Matemática','Que número representa o algarismo romano X?','10','5|50|100','10 é a resposta correcta.'],
    ['Matemática','Quanto é 15 por cento de 200?','30','15|20|40','30 é a resposta correcta.'],
    ['Matemática','Qual é o dobro de 37?','74','64|72|77','74 é a resposta correcta.'],
    ['Matemática','Quantos milímetros existem num centímetro?','10','100|5|1000','10 é a resposta correcta.'],
    ['Matemática','Qual é o resultado de 9 vezes 9?','81','72|90|99','81 é a resposta correcta.'],
    ['Matemática','Qual é a metade de 3/4?','3/8','1/2|2/3|1/4','3/8 é a resposta correcta.'],
    ['Matemática','Quantos lados tem um decágono?','Dez','Oito|Nove|Doze','Dez é a resposta correcta.'],
    ['Moçambique','Em que dia Moçambique celebra a independência?','25 de Junho','7 de Setembro|4 de Outubro|25 de Setembro','25 de Junho é a resposta correcta.'],
    ['Moçambique','Qual é a moeda oficial de Moçambique?','Metical','Rand|Kwanza|Escudo','Metical é a resposta correcta.'],
    ['Moçambique','Qual é a capital da província de Cabo Delgado?','Pemba','Nampula|Lichinga|Nacala','Pemba é a resposta correcta.'],
    ['Moçambique','Em que província fica o Parque Nacional da Gorongosa?','Sofala','Manica|Tete|Gaza','Sofala é a resposta correcta.'],
    ['Moçambique','Que grande rio atravessa a província de Tete?','Zambeze','Limpopo|Save|Rovuma','Zambeze é a resposta correcta.'],
    ['Moçambique','Qual é a língua oficial de Moçambique?','Português','Inglês|Suaíli|Francês','Português é a resposta correcta.'],
    ['Moçambique','Qual destas ilhas pertence ao arquipélago de Bazaruto?','Benguerra','Inhaca|Íbo|Moçambique','Benguerra é a resposta correcta.'],
    ['Moçambique','Em que província fica Vilankulo?','Inhambane','Gaza|Nampula|Maputo','Inhambane é a resposta correcta.'],
    ['Moçambique','Qual é a capital da província do Niassa?','Lichinga','Cuamba|Pemba|Tete','Lichinga é a resposta correcta.'],
    ['Moçambique','Que oceano banha a costa de Moçambique?','Oceano Índico','Oceano Atlântico|Oceano Pacífico|Oceano Ártico','Oceano Índico é a resposta correcta.'],
    ['Moçambique','A Ilha de Moçambique fica em que província?','Nampula','Sofala|Tete|Gaza','Nampula é a resposta correcta.'],
    ['Moçambique','Qual é a capital da província de Manica?','Chimoio','Tete|Quelimane|Inhambane','Chimoio é a resposta correcta.'],
    ['Moçambique','Qual é a capital da província de Gaza?','Xai-Xai','Chibuto|Maxixe|Nacala','Xai-Xai é a resposta correcta.'],
    ['Moçambique','Que lago Moçambique partilha com Malawi e Tanzânia?','Lago Niassa','Lago Chade|Lago Vitória|Lago Tanganica','Lago Niassa é a resposta correcta.'],
    ['Moçambique','Em que província fica a cidade da Beira?','Sofala','Zambézia|Tete|Maputo','Sofala é a resposta correcta.'],
    ['Moçambique','Qual é a capital da província da Zambézia?','Quelimane','Gurué|Mocuba|Milange','Quelimane é a resposta correcta.'],
    ['Moçambique','Qual é a capital da província de Tete?','Tete','Moatize|Chimoio|Lichinga','Tete é a resposta correcta.'],
    ['Moçambique','Que parque nacional fica no sul, junto ao vale do Limpopo?','Parque Nacional do Limpopo','Parque Nacional das Quirimbas|Parque Nacional de Banhine|Parque Nacional do Zinave','Parque Nacional do Limpopo é a resposta correcta.'],
    ['Moçambique','Em que cidade se encontra a estação ferroviária desenhada por Gustave Eiffel?','Maputo','Beira|Nampula|Pemba','Maputo é a resposta correcta.'],
    ['Moçambique','Qual é a capital da província de Nampula?','Nampula','Nacala|Angoche|Ilha de Moçambique','Nampula é a resposta correcta.'],
    ['Moçambique','Que barragem famosa se encontra no rio Zambeze?','Cahora Bassa','Massingir|Pequenos Libombos|Corumana','Cahora Bassa é a resposta correcta.'],
    ['Moçambique','Qual é a capital da província de Maputo?','Matola','Boane|Namaacha|Manhiça','Matola é a resposta correcta.'],
    ['História','Em que ano terminou a Segunda Guerra Mundial?','1945','1918|1939|1950','1945 é a resposta correcta.'],
    ['História','Em que ano caiu o Muro de Berlim?','1989','1975|1991|2001','1989 é a resposta correcta.'],
    ['História','Em que ano o ser humano chegou à Lua pela primeira vez?','1969','1959|1975|1981','1969 é a resposta correcta.'],
    ['História','Que civilização construiu as pirâmides de Gizé?','Egípcia','Romana|Inca|Mongol','Egípcia é a resposta correcta.'],
    ['História','Em que ano foi fundada a Organização das Nações Unidas?','1945','1919|1939|1955','1945 é a resposta correcta.'],
    ['História','Quem foi o primeiro presidente sul-africano após o apartheid?','Nelson Mandela','Desmond Tutu|Thabo Mbeki|F. W. de Klerk','Nelson Mandela é a resposta correcta.'],
    ['História','Em que século começou a Revolução Industrial na Grã-Bretanha?','Século XVIII','Século XV|Século XVI|Século XX','Século XVIII é a resposta correcta.'],
    ['História','Qual era a capital do Império Romano?','Roma','Atenas|Alexandria|Cartago','Roma é a resposta correcta.'],
    ['História','Que navegador chegou à Índia por via marítima em 1498?','Vasco da Gama','Pedro Álvares Cabral|Fernão de Magalhães|Bartolomeu Dias','Vasco da Gama é a resposta correcta.'],
    ['História','Em que ano começou a Primeira Guerra Mundial?','1914','1905|1918|1939','1914 é a resposta correcta.'],
    ['História','Que povo antigo desenvolveu a escrita cuneiforme na Mesopotâmia?','Sumérios','Fenícios|Vikings|Maias','Sumérios é a resposta correcta.'],
    ['História','Em que ano foi adoptada a Declaração de Independência dos EUA?','1776','1789|1815|1865','1776 é a resposta correcta.'],
    ['História','Qual foi a primeira cidade japonesa atingida por uma bomba atómica em guerra?','Hiroshima','Quioto|Osaka|Tóquio','Hiroshima é a resposta correcta.'],
    ['História','Que acontecimento de 1789 é associado ao início da Revolução Francesa?','Tomada da Bastilha','Queda de Constantinopla|Batalha de Waterloo|Congresso de Viena','Tomada da Bastilha é a resposta correcta.'],
    ['História','Qual era a principal língua escrita do Império Romano do Ocidente?','Latim','Grego moderno|Árabe|Sânscrito','Latim é a resposta correcta.'],
    ['História','Em que ano Moçambique proclamou a independência?','1975','1964|1980|1992','1975 é a resposta correcta.'],
    ['História','Que império construiu Machu Picchu?','Inca','Romano|Mali|Otomano','Inca é a resposta correcta.'],
    ['História','Em que ano foi assinada a Constituição dos Estados Unidos?','1787','1776|1804|1861','1787 é a resposta correcta.'],
    ['Geografia','Qual é o maior deserto quente do mundo?','Saara','Gobi|Kalahari|Atacama','Saara é a resposta correcta.'],
    ['Geografia','Em que continente se encontra o monte Kilimanjaro?','África','Ásia|Europa|América do Sul','África é a resposta correcta.'],
    ['Geografia','Qual é a linha imaginária de latitude zero?','Equador','Meridiano de Greenwich|Trópico de Câncer|Círculo Polar Árctico','Equador é a resposta correcta.'],
    ['Geografia','Qual é o maior país do mundo em área?','Rússia','Canadá|China|Estados Unidos','Rússia é a resposta correcta.'],
    ['Geografia','Qual é a capital do Egipto?','Cairo','Alexandria|Rabat|Trípoli','Cairo é a resposta correcta.'],
    ['Geografia','Em que continente fica a Patagónia?','América do Sul','África|Europa|Oceânia','América do Sul é a resposta correcta.'],
    ['Geografia','Qual é a capital da Coreia do Sul?','Seul','Busan|Tóquio|Pyongyang','Seul é a resposta correcta.'],
    ['Geografia','Qual é a grande ilha a leste de Moçambique?','Madagáscar','Cabo Verde|Islândia|Chipre','Madagáscar é a resposta correcta.'],
    ['Geografia','Que montanha é a mais alta acima do nível do mar?','Everest','K2|Kilimanjaro|Mont Blanc','Everest é a resposta correcta.'],
    ['Geografia','Qual é a capital do Canadá?','Otava','Toronto|Vancouver|Montreal','Otava é a resposta correcta.'],
    ['Geografia','Que mar separa a Europa do norte de África?','Mar Mediterrâneo','Mar do Norte|Mar Báltico|Mar Negro','Mar Mediterrâneo é a resposta correcta.'],
    ['Geografia','Em que país fica Buenos Aires?','Argentina','Chile|Uruguai|Peru','Argentina é a resposta correcta.'],
    ['Natureza','Que processo permite às abelhas transportar pólen entre flores?','Polinização','Evaporação|Digestão|Fermentação','Polinização é a resposta correcta.'],
    ['Natureza','Como se chama o conjunto de seres vivos e do ambiente onde vivem?','Ecossistema','Mineral|Continente|Atmosfera','Ecossistema é a resposta correcta.'],
    ['Natureza','Que animal é popularmente conhecido como rei da selva?','Leão','Tigre|Leopardo|Hiena','Leão é a resposta correcta.'],
    ['Natureza','Qual é o maior réptil vivo?','Crocodilo-de-água-salgada','Tartaruga-verde|Dragão-de-Komodo|Jibóia','Crocodilo-de-água-salgada é a resposta correcta.'],
    ['Natureza','Que tecido vegetal transporta água das raízes para as folhas?','Xilema','Floema|Casca|Pétala','Xilema é a resposta correcta.'],
    ['Natureza','Como se chama o movimento da Terra em torno do próprio eixo?','Rotação','Translação|Nutação|Precessão','Rotação é a resposta correcta.'],
    ['Natureza','Qual destes animais é um insecto?','Borboleta','Aranha|Escorpião|Caracol','Borboleta é a resposta correcta.'],
    ['Natureza','Que tipo de animal é a baleia?','Mamífero','Peixe|Réptil|Anfíbio','Mamífero é a resposta correcta.'],
    ['Natureza','Como se chama a camada rica em ozono na atmosfera?','Ozonosfera','Hidrosfera|Litosfera|Troposfera','Ozonosfera é a resposta correcta.'],
    ['Natureza','Que animal constrói barragens com troncos e ramos?','Castor','Lontra|Capivara|Panda','Castor é a resposta correcta.'],
    ['Natureza','Que ciclo inclui evaporação, condensação e precipitação?','Ciclo da água','Ciclo do carbono|Ciclo do azoto|Ciclo lunar','Ciclo da água é a resposta correcta.'],
    ['Natureza','Que planta armazena água no caule e vive em regiões áridas?','Cacto','Samambaia|Lótus|Musgo','Cacto é a resposta correcta.'],
    ['Ciência','Que instrumento observa objectos muito distantes no espaço?','Telescópio','Microscópio|Termómetro|Barómetro','Telescópio é a resposta correcta.'],
    ['Ciência','Qual é o centro de um átomo?','Núcleo','Electrosfera|Molécula|Protão isolado','Núcleo é a resposta correcta.'],
    ['Ciência','Que estado físico tem volume definido e forma variável?','Líquido','Sólido|Gasoso|Plasma','Líquido é a resposta correcta.'],
    ['Ciência','Como se chama a passagem do estado líquido para o gasoso?','Vaporização','Solidificação|Fusão|Condensação','Vaporização é a resposta correcta.'],
    ['Ciência','Qual é a unidade SI de energia?','Joule','Watt|Volt|Newton','Joule é a resposta correcta.'],
    ['Ciência','Que planeta tem os anéis mais visíveis?','Saturno','Mercúrio|Marte|Vénus','Saturno é a resposta correcta.'],
    ['Ciência','Que órgãos filtram o sangue e produzem urina?','Rins','Pulmões|Estômago|Pâncreas','Rins é a resposta correcta.'],
    ['Ciência','Que tipo de energia vem directamente da luz do Sol?','Energia solar','Energia geotérmica|Energia das marés|Energia nuclear','Energia solar é a resposta correcta.'],
    ['Ciência','Qual é a fórmula química do dióxido de carbono?','CO₂','H₂O|O₂|NaCl','CO₂ é a resposta correcta.'],
    ['Ciência','Como se chama a ciência que estuda os fósseis?','Paleontologia','Meteorologia|Botânica|Oceanografia','Paleontologia é a resposta correcta.'],
    ['Ciência','Que lente é normalmente usada numa lupa?','Convergente','Divergente|Plana|Opaca','Convergente é a resposta correcta.'],
    ['Ciência','Qual é a principal fonte de energia do ciclo da água?','Sol','Lua|Núcleo terrestre|Vento','Sol é a resposta correcta.'],
    ['Tecnologia','Que linguagem é usada para criar aplicações Flutter?','Dart','Kotlin|Swift|Ruby','Dart é a resposta correcta.'],
    ['Tecnologia','Que tecnologia liga dispositivos a redes locais sem fios?','Wi-Fi','HDMI|VGA|SATA','Wi-Fi é a resposta correcta.'],
    ['Tecnologia','Que unidade mede habitualmente a velocidade de uma rede?','Megabits por segundo','Litros por minuto|Graus Celsius|Watts por hora','Megabits por segundo é a resposta correcta.'],
    ['Tecnologia','Para que serve um código QR?','Guardar informação que a câmara pode ler','Aumentar memória RAM|Carregar a bateria|Proteger o ecrã','Guardar informação que a câmara pode ler é a resposta correcta.'],
    ['Tecnologia','O que é autenticação de dois factores?','Usar duas provas de identidade','Usar duas palavras-passe iguais|Criar duas contas|Desligar o Wi-Fi','Usar duas provas de identidade é a resposta correcta.'],
    ['Tecnologia','Que tecnologia permite pagamentos sem contacto em muitos telemóveis?','NFC','VGA|FTP|DNS','NFC é a resposta correcta.'],
    ['Tecnologia','Qual é o formato de documento portátil mais conhecido?','PDF','PSD|MP3|APK','PDF é a resposta correcta.'],
    ['Tecnologia','Para que serve um endereço IP?','Identificar um dispositivo numa rede','Medir o tamanho do ecrã|Aumentar o GPS|Guardar palavras-passe','Identificar um dispositivo numa rede é a resposta correcta.'],
    ['Tecnologia','O que é código-fonte?','Instruções de um programa','Uma fotografia|Um cabo USB|Um tipo de ecrã','Instruções de um programa é a resposta correcta.'],
    ['Tecnologia','Que componente executa instruções e cálculos num computador?','Processador','Altifalante|Teclado|Ventoinha','Processador é a resposta correcta.'],
    ['Língua','Qual é o plural correcto de pão?','Pães','Pãos|Pãoses|Pãezes','Pães é a resposta correcta.'],
    ['Língua','Que classe de palavra expressa uma acção ou estado?','Verbo','Adjectivo|Artigo|Preposição','Verbo é a resposta correcta.'],
    ['Língua','Qual é o antónimo de generoso?','Egoísta','Bondoso|Amável|Solidário','Egoísta é a resposta correcta.'],
    ['Língua','Como se chama a palavra que substitui um nome?','Pronome','Verbo|Advérbio|Conjunção','Pronome é a resposta correcta.'],
    ['Língua','Qual é o aumentativo comum de casa?','Casarão','Casinha|Casebre|Casita','Casarão é a resposta correcta.'],
    ['Língua','Que sinal separa elementos de uma enumeração?','Vírgula','Ponto de interrogação|Travessão|Parênteses','Vírgula é a resposta correcta.'],
    ['Língua','Como se chama uma palavra formada pela união de duas palavras?','Palavra composta','Sinónimo|Antónimo|Interjeição','Palavra composta é a resposta correcta.'],
    ['Língua','Qual é o feminino tradicional de actor?','Actriz','Actora|Actante|Actoraça','Actriz é a resposta correcta.'],
    ['Língua','Que tipo de frase termina normalmente com ponto de exclamação?','Exclamativa','Interrogativa|Declarativa negativa|Condicional','Exclamativa é a resposta correcta.'],
    ['Língua','Como se chama a repetição de sons consonânticos próximos?','Aliteração','Metáfora|Hipérbole|Ironia','Aliteração é a resposta correcta.'],
    ['Cultura','Que arte japonesa consiste em arranjos florais?','Ikebana','Origami|Haiku|Kabuki','Ikebana é a resposta correcta.'],
    ['Cultura','Que instrumento tem teclas, cordas e martelos?','Piano','Flauta|Trompete|Tambor','Piano é a resposta correcta.'],
    ['Cultura','Como se chama o poema tradicional japonês de três versos 5-7-5?','Haiku','Soneto|Épico|Ode','Haiku é a resposta correcta.'],
    ['Cultura','Que estilo de pintura utiliza pequenos pontos de cor?','Pontilhismo','Cubismo|Barroco|Realismo','Pontilhismo é a resposta correcta.'],
    ['Cultura','Qual destes é um instrumento da família dos metais?','Trompete','Violoncelo|Harpa|Tambor','Trompete é a resposta correcta.'],
    ['Cultura','Que espectáculo combina música, canto e representação?','Musical','Documentário|Exposição|Conferência','Musical é a resposta correcta.'],
    ['Cultura','Que língua está tradicionalmente associada ao fado?','Português','Espanhol|Italiano|Alemão','Português é a resposta correcta.'],
    ['Cultura','Como se chama a arte de contar histórias com imagens sequenciais?','Banda desenhada','Escultura|Cerâmica|Arquitectura','Banda desenhada é a resposta correcta.'],
    ['Cultura','Que material é muito usado em instrumentos de corda acústicos?','Madeira','Borracha|Vidro|Papel','Madeira é a resposta correcta.'],
    ['Cultura','Como se chama o local onde se conservam e expõem obras de arte?','Museu','Estádio|Aeroporto|Mercado','Museu é a resposta correcta.'],
    ['Desporto','Quantos jogadores de cada equipa iniciam normalmente um jogo de futebol?','Onze','Nove|Dez|Doze','Onze é a resposta correcta.'],
    ['Desporto','Em que desporto se usa uma bola e um cesto elevado?','Basquetebol','Andebol|Rugby|Voleibol','Basquetebol é a resposta correcta.'],
    ['Desporto','Que país acolheu os primeiros Jogos Olímpicos modernos em 1896?','Grécia','França|Reino Unido|Itália','Grécia é a resposta correcta.'],
    ['Desporto','Em que modalidade se compete numa piscina por tempo e distância?','Natação','Ginástica|Esgrima|Ciclismo','Natação é a resposta correcta.'],
    ['Desporto','Que equipamento protege a cabeça de um ciclista?','Capacete','Cotoveleira|Caneleira|Luvas','Capacete é a resposta correcta.'],
    ['Desporto','Qual é a duração regulamentar de um jogo de futebol sem compensação?','90 minutos','60 minutos|80 minutos|100 minutos','90 minutos é a resposta correcta.'],
    ['Desporto','Em que desporto se utiliza um volante em vez de uma bola?','Badminton','Ténis|Squash|Rugby','Badminton é a resposta correcta.'],
    ['Desporto','Qual destas modalidades é praticada sobre gelo com patins?','Patinagem artística','Surf|Andebol|Golfe','Patinagem artística é a resposta correcta.'],
    ['Desporto','Como se chama a competição de ciclismo por etapas realizada em França?','Tour de France','Giro d\'Italia|Vuelta a España|Paris-Dakar','Tour de France é a resposta correcta.'],
    ['Desporto','Em que desporto se usa uma bola oval para marcar ensaios?','Rugby','Ténis|Golfe|Hóquei','Rugby é a resposta correcta.'],
  ];
  for (final fact in moreFacts) {
    questions.add(_buildQuestion(fact[0], fact[1], fact[2], fact[3].split('|'), seed++, fact[4]));
  }

  for (final fact in facts) {
    questions.add(_buildQuestion(
      fact[0], fact[1], fact[2], fact[3].split('|'), seed++, fact[4],
    ));
  }

  return List.unmodifiable(questions);
}

final List<QuizQuestion> quizQuestionBank = buildQuizQuestionBank();
