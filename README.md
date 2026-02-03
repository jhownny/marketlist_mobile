
<div align="center">

  # 🛒 MarketList Mobile
  
  **Sua lista de compras inteligente, integrada e em tempo real.**
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
  [![Dart](https://img.shields.io/badge/Dart-3.0%2B-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
  [![PHP Backend](https://img.shields.io/badge/Backend-PHP%208-777BB4?style=for-the-badge&logo=php&logoColor=white)](https://php.net/)
  [![MySQL](https://img.shields.io/badge/Database-MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)](https://mysql.com/)
  
  <p align="center">
    <a href="#sobre">Sobre</a> •
    <a href="#funcionalidades">Funcionalidades</a> •
    <a href="#rodar">Como Rodar</a> •
    <a href="#tecnologias">Tecnologias</a> •
    <a href="#autor">Autor</a>
  </p>
</div>

---
<div id="sobre"></div>

## 📱 Sobre o Projeto

O **MarketList Mobile** é a interface visual para o ecossistema MarketList. Desenvolvido em **Flutter**, ele consome a mesma API utilizada pelo nosso Bot do Telegram, permitindo que os usuários visualizem e gerenciem suas listas de compras de forma sincronizada em qualquer dispositivo.

O objetivo é oferecer uma experiência nativa, rápida e fluida, mantendo a integridade dos dados através de uma API RESTful segura em PHP.

---
<!--
## 📸 Screenshots

<div align="center">
  <img src="" alt="" height="400">
  <img src="" alt="" height="400">
</div>

---
-->
<div id="funcionalidades"></div>

## 🚀 Funcionalidades

- [x] **Sincronização em Tempo Real:** Dados consumidos diretamente do MySQL via API PHP.
- [x] **Visualização Clara:** Listagem de produtos com preços, quantidades e status.
- [x] **Indicadores Visuais:** Diferenciação clara entre itens pendentes e comprados (check/riscado).
- [x] **Segurança:** Comunicação via API Key (Header `x-api-key`) e HTTPS.
- [ ] **Modo Offline:** (Em breve) Cache local para ver a lista sem internet.
- [ ] **Gestão de Grupos:** (Em breve) Alternar entre diferentes listas de compras.

---
<div id="tecnologias"></div>

## 🛠 Tecnologias Utilizadas

Este projeto foi desenvolvido com as seguintes tecnologias:

### Mobile
* **[Flutter](https://flutter.dev/):** Framework para UI nativa.
* **[Dart](https://dart.dev/):** Linguagem otimizada para UI.
* **[Http](https://pub.dev/packages/http):** Para consumo de API REST.
* **[Flutter Dotenv](https://pub.dev/packages/flutter_dotenv):** Gerenciamento seguro de variáveis de ambiente.

### Backend & Infra
* **PHP:** API RESTful.
* **MySQL:** Banco de dados relacional.

---
<div id="rodar"></div>

## 💻 Como Rodar o Projeto

### Pré-requisitos
Antes de começar, você precisa ter instalado em sua máquina:
* [Git](https://git-scm.com)
* [Flutter SDK](https://flutter.dev/docs/get-started/install)
* [VS Code](https://code.visualstudio.com/) ou Android Studio

### Passo a Passo

1. **Clone o repositório**
 ```bash
 git clone https://github.com/jhownny/marketlist_mobile.git
 cd marketlist_mobile

```

2. **Instale as dependências**
```bash
flutter pub get

```


3. **Configure as Variáveis de Ambiente**
Crie um arquivo chamado `.env` na raiz do projeto e adicione suas credenciais:
```env
API_URL=[https://seusite.com.br/api.php]
API_KEY=sua_chave_secreta_aqui

```


4. **Execute o projeto**
Conecte seu dispositivo ou inicie um emulador e rode:
```bash
flutter run

```

---


<div id="autor" align="center">
  <p> 👨‍💻 Desenvolvido por Jhonata (Jhownny). </p>  
</div>

