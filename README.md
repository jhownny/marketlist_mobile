
<div align="center">

  <p align="center"> <img src="./assets/Text-MarketList-logo2_Red-GitHub.png" alt="LOOGO MARKETLIST" width="256"> </p>

  <!--# 🛒 MarketList Mobile-->
  
  **Sua lista de compras inteligente, integrada e em tempo real.**
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
  [![Dart](https://img.shields.io/badge/Dart-3.0%2B-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
  [![PHP Backend](https://img.shields.io/badge/Backend-PHP%208-777BB4?style=for-the-badge&logo=php&logoColor=white)](https://php.net/)
  [![MySQL](https://img.shields.io/badge/Database-MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)](https://mysql.com/)
  [![GPLv3 License](https://img.shields.io/badge/License-GPLv3-A32638?style=for-the-badge&logo=gnu&logoColor=white)](https://www.gnu.org/licenses/gpl-3.0)
  
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

O **MarketList Mobile** é a interface oficial e principal do ecossistema MarketList. Desenvolvido em **Flutter**, ele consome uma API própria e dedicada, permitindo que os usuários criem, visualizem e gerenciem suas listas de compras de forma autônoma e segura direto do smartphone.

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
- [x] **Modo Offline:** Cache local para ver a lista sem internet.
- [x] **Gestão de Grupos:** Alternar e editar diferentes listas de compras.
- [x] **Histórico de Listas:** Manter um histórico de listas anteriores para comparação.
- [x] **Verificação de Email:** Mandar um codigo de verificação para confirmar a existencia do email.
- [x] **Recuperação de Senha:** Fluxo de "Esqueci minha senha" com validação segura via código OTP temporário enviado ao e-mail.
- [x] **Exclusão de Conta (LGPD/GDPR):** Opção nativa para o usuário apagar permanentemente sua conta e rastros de dados no banco, atendendo às políticas de privacidade.
- [x] **Orçamento por Lista:** Definir um limite de gastos para o grupo e acompanhar o saldo (positivo ou negativo) em tempo real.

### ⏳ Metas Futuras (Roadmap)

- [ ] **Compartilhamento de Recibo:** Exportar o comprovante de compras finalizadas para envio via WhatsApp e outros apps.
- [ ] **Dashboard Financeiro:** Aba de estatísticas com gráficos visuais detalhando os gastos totais do usuário por mês e por grupos de compras.

- [ ] **Listas Compartilhadas:** Permitir que contas diferentes gerenciem e editem o mesmo grupo de compras de forma colaborativa.

      
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
API_URL=https://seusite.com.br/api.php
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

