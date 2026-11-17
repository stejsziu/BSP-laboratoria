\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{sprawozdanie}
\LoadClass[12pt, twoside]{article}
%
% =========================================================================================
% BIBLIOTEKI ITP:
%
%
% photos and graphics:
\RequirePackage{graphicx}
\RequirePackage{graphics}
% margins:
\RequirePackage[left = 2cm, right = 2cm, top = 2cm, bottom = 3cm]{geometry}
% language settings and coding:
%\RequirePackage{fixltx2e}
\RequirePackage[T1]{fontenc}
\RequirePackage[utf8]{inputenc}
% table of contents changes:
\RequirePackage[hidelinks]{hyperref}
\RequirePackage{tocloft}
% manual paragraph indents
\RequirePackage{tabto}
% math symbols and tools:
\RequirePackage{amsmath}
\RequirePackage{mathtools}
% fancy header/footer:
\RequirePackage{fancyhdr}
% create floating environemtns and boxes
% for better maneuverability:
\RequirePackage{float}
\RequirePackage[export]{adjustbox}
% captions for figures:
\RequirePackage{caption}
\RequirePackage{subcaption}
% fonts:
\RequirePackage{lmodern}
\RequirePackage{sourceserifpro} % Load Source Serif Pro
\RequirePackage{ragged2e} % Improved text justification
% where tf did those come from:
\RequirePackage[table,xcdraw]{xcolor}
\RequirePackage{tikz}
\RequirePackage{ragged2e}
% language and it moves over alone characters
% from the end of a line
\RequirePackage[polish]{babel}
\RequirePackage{tabularx}
%\RequirePackage{everypage}
\RequirePackage{array} % Make sure this package is included
\RequirePackage{pifont}
\RequirePackage{xparse}
%
% =========================================================================================
% VISUAL SETTINGS (NUMBERING, EMPTY SPACES, ETC)
%
%
\setlength{\abovedisplayskip}{5px}
\setlength{\belowdisplayskip}{5px}
%
%\captionsetup[figure]{labelformat=empty} % Removes "Figure" label from captions
% remove red color from toc hyperlinks
\DeclareOption{red}{\renewcommand{\headlinecolor}{\color{slcolor}}}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax
%
% =========================================================================================
% TITLE PAGE
%
%
% important information commands
\newcommand{\class}[1]{\gdef\@class{#1}}%
\newcommand{\@class}{\@latex@warning@no@line{No \noexpand\class given}}
%
\newcommand{\deadline}[1]{\gdef\@deadline{Data oddania: \textbf{#1}}}%
\newcommand{\@deadline}{\@latex@warning@no@line{No \noexpand\deadline given}}
%
\newcommand{\instructor}[1]{\gdef\@instructor{Prowadzący: #1}}%
\newcommand{\@instructor}{\@latex@warning@no@line{No \noexpand\instructor given}}
%
%
\renewcommand{\maketitle}{%
\begin{titlepage}
\newgeometry{margin = 2cm}
%
% LOGO POLIBUDY
\begin{minipage}{0.75\textwidth}
\begin{center}
    {\fontsize{31}{20}\fontseries{bx}\selectfont Politechnika Warszawska}\\[5pt]
\end{center}
\begin{center}
    {\fontsize{15}{20}\fontseries{n}\selectfont \hspace{10px} W\hfill \hspace{3px} Y \hfill D \hfill Z \hfill I \hfill A \hfill Ł \hspace{20px} M \hfill E \hfill C \hfill H \hfill A \hfill N \hfill I \hfill C \hfill Z \hfill N \hfill Y} \hspace{10px} \\[3pt]
    {\fontsize{15}{20}\fontseries{n}\selectfont E \hfill N \hfill E \hfill R \hfill G \hfill E \hfill T \hfill Y \hfill K \hfill I \hspace{20px} I \hspace{20px} L \hfill O \hfill T \hfill N \hfill I \hfill C \hfill T \hfill W \hfill A}\\[3pt]
%
    %{\fontsize{10}{20}\fontseries{n}\selectfont Instytut Techniki Lotniczej i Mechaniki Stosowanej}\\[5pt]
    {\fontsize{10}{20}\fontseries{n}\selectfont Instytut Techniki Lotniczej i Mechaniki Stosowanej}\\[5pt]
\end{center}
\end{minipage}
\hspace{15px}
\hfill
\begin{minipage}{0.25\textwidth}
    \ifdarkmode % ciemne logo % trim options: [left botoom right top]
        %
        \noindent\includegraphics[width = 0.6\textwidth]{pliki/jp2.png}
    \else                                                  % margin of 20 pt each side
        \noindent\includegraphics[page = 27, scale = 0.3, trim= 230 100 230 100, clip]{logo/pw_kod_wizualny.pdf}
        %\noindent\includegraphics[width = 0.6\textwidth]{pliki/jp2.png}
    \fi
\end{minipage}
\vspace{50px}
%
% TITLE AND AUTHORS
\begin{center}
%{\fontsize{22}{50}\fontseries{bx}\selectfont\@class}\\[10pt]
{\fontsize{22}{50}\fontseries{bx}\selectfont Sprawozdanie z Laboratorium}\\[10pt]
{\fontsize{30}{60}\selectfont\sc\@title}\\[10pt]\vfill
%{\fontsize{22}{40}\selectfont\@author\fontseries{n}\selectfont}\\\vfill
\end{center}

\vfill
%
%
\input{tabela_grupa}
\vfill
%
% BOTTOM ENTRIES
\noindent
{\fontsize{18}{20}\selectfont\@instructor\fontseries{n}\selectfont}\\[10pt]
{\fontsize{18}{20}\selectfont\@deadline\fontseries{n}\selectfont}
\end{titlepage}
\restoregeometry
}
%
% =========================================================================================
% SPIS TRESCI:
%
%
\renewcommand{\contentsname}{Spis treści}
\renewcommand{\cftsecleader}{\cftdotfill{\cftdotsep}} % dots for sections and subsections
%\renewcommand{\cftsubsecleader}{\hfill} % remove dots for subsections
%\renewcommand{\cftsubsubsecleader}{\hfill} % remove dots for subsubsections
% hypersetup zrobiony jest w ciemnym trybie
%
% =========================================================================================
% FONTS:
%
%
%\renewcommand{\familydefault}{\ttdefault} % Keep typewriter font
%\renewcommand{\normalsize}{\justifying} % Justify text properly
%\renewcommand{\ttdefault}{lmtt} % Use Latin Modern Typewriter font
%\hyphenchar\font=`\- % Allow hyphenation in monospaced text
%
\renewcommand{\cftsecfont}{\bfseries} % bold section titles
\setlength{\cftbeforesecskip}{10pt} % space before each section entry
%
% =========================================================================================
% DARKMODE:
%
%
\newif\ifdarkmode
\DeclareOption{theme=dark}{\darkmodetrue} % Enable dark mode
\DeclareOption{theme=light}{\darkmodefalse} % Enable light mode (default)
\ProcessOptions\relax
% 
\ifdarkmode % dark mode settings
    \pagecolor{black}   % Set background to black
    \color{white}       % Set text color to white
    \def\logoPolibudy{logo/logo-polibudy-dark.png}   % Set dark logo
    \def\logoMeil{logo/logo-meil-dark.png}           % Set dark logo
    %
    \hypersetup % Ensure the TOC text is visible in dark mode
    {
        colorlinks=true,
        linkcolor=white, % Set TOC link color to white
        citecolor=blue, % Set citation link color to green
        urlcolor=blue    % Set URL link color to green
    }
    %
    \newcommand{\tocfontcolor}{\color{white}}  % Ensure TOC entries are white
    %
\else
    \pagecolor{white}   % Set background to white (light mode)
    \color{black}       % Set text color to black (light mode)
    \def\logoPolibudy{logo/logo-polibudy.png}        % Set light logo
    \def\logoMeil{logo/logo-meil.png}                % Set light logo
    %
    % Default TOC settings
    \hypersetup
    {
        colorlinks=true,
        linkcolor=black, % Set TOC link color to black
        citecolor=blue, % Set citation link color to green
        urlcolor=blue    % Set URL link color to green
    }
    %
    \newcommand{\tocfontcolor}{\color{black}}  % Ensure TOC entries are black
\fi
%
% Apply the color for the TOC sections using \tocfontcolor
\renewcommand{\tableofcontents}{
    \begingroup
    \tocfontcolor
    \tableofcontents
    \endgroup
}
%
% =========================================================================================
% USTAWIENIA GORY I DOLU STRONY POD KRESKAMI
% HEADER AND FOOTER
%
%
\fancyhf{}
\fancyhead[RE]{\nouppercase{\scshape \leftmark}}
\fancyhead[LO]{\nouppercase{\scshape \rightmark}}
\fancyhead[LE]{\@class}
\fancyhead[LO]{\@title}
\fancyhead[R]{\@author}
%
\ifdarkmode
    \fancyfoot[LO]{\makebox[0pt][l]{\raisebox{30px}{\includegraphics[scale = 0.17 ]{logo/logo-meil-dark.png}}}}
    \fancyfoot[RE]{\makebox[0pt][l]{\raisebox{30px}{\includegraphics[scale = 0.17 ]{logo/logo-meil-dark.png}}}}
\else
    \fancyfoot[LO]{\makebox[0pt][l]{\raisebox{30px}{\includegraphics[scale = 0.17 ]{logo/logo-meil.png}}}}
    \fancyfoot[RE]{\makebox[0pt][l]{\raisebox{30px}{\includegraphics[scale = 0.17 ]{logo/logo-meil.png}}}}
\fi
%
\fancyfoot[RO]{\makebox[0pt][r]{\raisebox{50px}{\thepage}}}
\fancyfoot[LE]{\makebox[0pt][r]{\raisebox{50px}{\thepage}}}
%
\pagestyle{fancy}
%
% =========================================================================================