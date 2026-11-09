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

  for (final fact in facts) {
    questions.add(_buildQuestion(
      fact[0], fact[1], fact[2], fact[3].split('|'), seed++, fact[4],
    ));
  }

  return List.unmodifiable(questions);
}

final List<QuizQuestion> quizQuestionBank = buildQuizQuestionBank();
