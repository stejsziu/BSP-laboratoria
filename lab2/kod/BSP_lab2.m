1;  % script file marker (functions below must be defined before use)
% =====================================================================
%  Badanie charakterystyk smigla - opracowanie wynikow (pkt 5.2)
%  Octave. Dane: plik .ods / .xlsx / .csv (separator ';', przecinek dziesietny)
% =====================================================================


function ok = save_fig_as(fn, devs)
  % probuje kolejno rozne urzadzenia 'print' i raportuje wynik
  ok = false;
  for d = 1:numel(devs)
    try
      print(fn, devs{d});
      if exist(fn, "file") == 2
        printf("  OK  %-32s (%s)\n", fn, devs{d});
        ok = true; return;
      end
    catch err
      printf("  --  %s przez %s nie wyszlo: %s\n", fn, devs{d}, strtrim(err.message));
    end
  end
  printf("  !!  NIE ZAPISANO: %s\n", fn);
end

% ------------------------- USTAWIENIA --------------------------------
% przejdz do folderu ze skryptem, zeby pliki wynikowe (PNG/PDF/CSV) trafialy obok niego
script_dir = fileparts(mfilename("fullpath"));
if ~isempty(script_dir), cd(script_dir); end
printf("smiglo.m  [wersja z eksportem PDF]\nFolder roboczy: %s\n", pwd);
fname         = "BSP_2026Z_lab2_pomiary_28_10_26.csv";   % lub "pomiary.ods"
D             = 6.00 * 0.0254;   % [m] smiglo 6045: srednica 6.00 in (Quanser/Cobra)
edges_per_rev = 1;               % ile zboczy sygnalu z oscyloskopu przypada na 1 obrot
pa            = 760 * 133.322;   % [Pa] cisnienie atmosferyczne (760 mmHg z arkusza)
R_air         = 287.05;          % [J/(kg K)] stala gazowa powietrza
g             = 9.80665;         % [m/s^2]
exclude       = [5 13];          % numery pomiarow pomijane (5 - nie krecilo sie, 13 - podejrzany)
save_figs     = true;            % zapis wykresow do PNG
save_pdf      = true;            % zapis wykresow do PDF (wektorowo) + wspolny plik wykresy_all.pdf
save_table    = true;            % zapis tabeli wynikow do wyniki.csv

% ------------------------- WCZYTANIE ---------------------------------
function data = load_measurements(fname)
  if exist(fname, "file") ~= 2
    error("Nie znaleziono pliku '%s' w folderze %s", fname, pwd);
  end
  [~, ~, ext] = fileparts(fname);
  if any(strcmpi(ext, {".ods", ".xlsx", ".xls"}))
    pkg load io;
    [~, ~, raw] = xlsread(fname, 1);
    printf("Arkusz: %d wierszy x %d kolumn\n", size(raw, 1), size(raw, 2));
  else
    txt   = fileread(fname);
    txt   = strrep(txt, char(239,187,191), "");           % BOM
    lines = strsplit(txt, {"\r\n", "\n", "\r"});
    lines = lines(~cellfun(@isempty, strtrim(lines)));
    % wykrycie rozdzielacza: ';' > tab > ','
    delim = ",";
    for c = {";", "\t"}
      if mean(cellfun(@(l) numel(strfind(l, c{1})), lines)) >= 5
        delim = c{1}; break;
      end
    end
    printf("Plik CSV: %d linii, rozdzielacz '%s'\n", numel(lines), delim);
    raw = cell(numel(lines), 11);
    for i = 1:numel(lines)
      f = strsplit(lines{i}, delim, "CollapseDelimiters", false);
      f(end+1:11) = {""};
      raw(i, :) = strrep(f(1:11), "\"", "");
    end
  end
  if size(raw, 2) < 11, raw(:, end+1:11) = {NaN}; end
  raw  = raw(:, 1:11);
  data = nan(size(raw));
  for k = 1:numel(raw)
    c = raw{k};
    if isnumeric(c) && isscalar(c)
      data(k) = c;
    elseif ischar(c)
      data(k) = str2double(strrep(strtrim(c), ",", "."));   % "-" i tekst -> NaN
    end
  end
  data = data(~isnan(data(:, 1)), :);       % zostaja tylko wiersze z numerem pomiaru
  printf("Wczytano %d wierszy z danymi.\n", rows(data));
  if isempty(data)
    error(["Nie znaleziono zadnego wiersza z danymi (pierwsza kolumna ma byc numerem pomiaru).\n" ...
           "Sprawdz nazwe pliku, rozdzielacz i czy dane nie zaczynaja sie w innej kolumnie."]);
  end
end

data = load_measurements(fname);

% kolumny: 1 nr | 2 U | 3 PWM | 4 I | 5 f_obr [Hz] | 6 T [N] | 7 M [Ncm]
%          8 q za smiglem [Pa] | 9 q tunelu [Pa] | 10 nastawa tunelu | 11 temp [C]
no   = data(:, 1);
U    = data(:, 2);
pwm  = data(:, 3);
I    = data(:, 4);
n    = data(:, 5) / edges_per_rev;      % [obr/s]
T    = data(:, 6);                      % [N]
M    = data(:, 7) / 100;                % [Nm]  (Ncm -> Nm)
q_w  = data(:, 8);                      % [Pa] cisnienie dynamiczne za smiglem
q_t  = data(:, 9);                      % [Pa] cisnienie dynamiczne w tunelu
Tc   = data(:, 11);                     % [C]
q_w(q_w < 0) = NaN;

% ------------------------- OBLICZENIA --------------------------------
tun_on = ~isnan(q_t);

% gestosc powietrza  rho = pa / (R * Ta)
rho = pa ./ (R_air * (Tc + 273.15));

% predkosc napywu (tunel) i predkosc w strumieniu zasmiglowym  v = sqrt(2 q / rho)
V = zeros(size(no));
V(tun_on) = sqrt(2 * q_t(tun_on) ./ rho(tun_on));
v_w = sqrt(2 * q_w ./ rho);

% moce i sprawnosci
Ne      = U .* I;                       % [W] moc elektryczna
Pmech   = M .* 2*pi .* n;               % [W] moc na wale  (M * omega)
etaT    = (T / g * 1000) ./ Ne;         % [g/W] zdolnosc do wytwarzania ciagu
eta_m   = Pmech ./ Ne;                  % sprawnosc silnika + sterownika
eta_zn  = T .* V ./ Ne;                 % sprawnosc zespolu napedowego  (T*V)/(U*I)
eta_jet = rho * pi * D^2 .* v_w.^3 ./ (8 * Ne);   % moc strumienia / moc el.
        % UWAGA: w instrukcji jest /4, ale 0.5*rho*Q*v^2 z Q = pi*D^2/4*v daje /8

% wspolczynniki aerodynamiczne
lambda = V ./ (pi * n * D);             % n w obr/s  (wzor z "60" jest dla n w obr/min)
Ct     = T ./ (rho .* n.^2 * D^4);
Cn     = M ./ (rho .* n.^2 * D^5);
Cn_ok  = Cn; Cn_ok(Cn_ok <= 0) = NaN;  % moment <= 0 -> blad pomiaru, brak sprawnosci
eta    = lambda .* Ct ./ (2 * Cn_ok);   % sprawnosc aerodynamiczna smigla
eta_chk = T .* V ./ Pmech;              % kontrola: powinno byc = eta
eta(Pmech <= 0) = NaN;

% ------------------------- SERIE -------------------------------------
valid = ~ismember(no, exclude) & ~isnan(n);
A = valid & abs(U - 11.1) < 0.05 & ~tun_on;     % 11.1 V, bez tunelu
B = valid & abs(U - 9.5)  < 0.05 & ~tun_on;     %  9.5 V, bez tunelu
C = valid & tun_on;                             % 11.1 V, tunel wlaczony
bad = ismember(no, exclude) & ~isnan(n);        % pominiete, ale rysowane jako 'x'

% ------------------------- DANE PRODUCENTA ----------------------------
% Cobra CM-2206/20, Kv=2100, 11.1 V, smiglo HQ 6x4.5
% kolumny: throttle[%]  I[A]  P[W]  RPM  ciag[g]  g/W
cobra = [ 10  0.43   4.75   3838   33.4  7.03;
          20  0.97  10.78   5774   77.9  7.23;
          30  1.68  18.65   7279  130.9  7.02;
          40  2.70  29.96   8809  192.8  6.44;
          50  4.22  46.83  10489  278.4  5.94;
          60  6.06  67.30  11981  365.1  5.43;
          70  8.35  92.63  13417  457.3  4.94;
          80 11.34 125.92  15021  577.8  4.59;
          90 14.97 166.11  16509  694.6  4.18;
         100 16.98 188.47  17233  762.1  4.04];
cb_n   = cobra(:, 4) / 60;              % [obr/s]
cb_T   = cobra(:, 5) / 1000 * g;        % [N]
cb_I   = cobra(:, 2);                   % [A]
cb_eta = cobra(:, 6);                   % [g/W]

% Quanser QDrone, model nieliniowy (Drone Parametrization, rown. 8-9)
%   F = Ct*(w + wf)^2 + Fb  (w w RPM),   M = F / k_tau
Ct_Q = 2.0784e-8;  wf_Q = 1004.5;  Fb_Q = -0.2046;  k_tau = 81.0363;
nQ   = linspace(40, 300, 100)';         % [obr/s]  (ciag > 0 dla w > 2132.6 RPM)
TQ   = Ct_Q * (nQ*60 + wf_Q).^2 + Fb_Q; % [N]
MQ   = TQ / k_tau;                      % [Nm]

% ------------------------- TABELA ------------------------------------
printf("\nrho = %.3f kg/m^3 (srednio),  V_tunel = %.2f m/s\n\n", mean(rho), max(V));
printf(" nr   U[V]  PWM   n[1/s]  T[N]   M[Nm]   Ne[W]  etaT[g/W]  V[m/s] v_zas  lambda   Ct      Cn     eta    eta_m\n");
for k = 1:numel(no)
  printf("%3d %6.1f %5.1f %7.1f %6.2f %7.4f %7.1f %8.2f %8.2f %6.1f %7.3f %7.4f %7.4f %6.3f %6.3f\n", ...
         no(k), U(k), pwm(k), n(k), T(k), M(k), Ne(k), etaT(k), V(k), v_w(k), ...
         lambda(k), Ct(k), Cn(k), eta(k), eta_m(k));
end
printf("\nKontrola: max |eta - T*V/(M*omega)| = %.2e\n", max(abs(eta - eta_chk)));

% ------------------------- PORÓWNANIE Z PRODUCENTEM ------------------
% (seria A: 11.1 V, V=0 - te same warunki co w tescie Cobry)
T_cb   = interp1(cb_n, cb_T,   n(A));
eta_cb = interp1(cb_n, cb_eta, n(A));
I_cb   = interp1(cb_n, cb_I,   n(A));
T_qd   = Ct_Q * (n(A)*60 + wf_Q).^2 + Fb_Q;
M_qd   = T_qd / k_tau;
printf("\nPorownanie z producentem (11.1 V, V=0), te same n:\n");
printf(" nr  n[1/s]  T[N]  T_Cobra  dT[%%]  T_Quanser  dT[%%]  | etaT  eta_Cobra | I[A]  I_Cobra | M[Ncm] M_Quanser\n");
ia = find(A);
for k = 1:numel(ia)
  j = ia(k);
  printf("%3d %7.1f %5.2f %7.2f %6.1f %9.2f %6.1f  | %5.2f %8.2f | %5.1f %7.2f | %6.2f %8.2f\n", ...
    no(j), n(j), T(j), T_cb(k), 100*(T(j)-T_cb(k))/T_cb(k), T_qd(k), 100*(T(j)-T_qd(k))/T_qd(k), ...
    etaT(j), eta_cb(k), I(j), I_cb(k), M(j)*100, M_qd(k)*100);
end

% ------------------------- WYKRESY -----------------------------------
mk = @(h) set(h, "linewidth", 1.5, "markersize", 7);
leg = {"11.1 V, V=0", "9.5 V, V=0", "11.1 V, z tunelem", "pominiete"};

figure(1); clf; hold on;                                   % T(n)
mk(plot(n(A), T(A), "o-b")); mk(plot(n(B), T(B), "s-r")); mk(plot(n(C), T(C), "^-g"));
plot(n(bad), T(bad), "kx", "markersize", 9);
plot(cb_n, cb_T, "k--", "linewidth", 1.5);
plot(nQ, TQ, "m-.", "linewidth", 1.5);
xlabel("n [obr/s]"); ylabel("T [N]"); title("Sila ciagu T = T(n)"); grid on;
xlim([40 300]);
legend([leg, {"Cobra (HQ 6x4.5, 11.1 V)", "Quanser (model)"}], "location", "northwest");

figure(2); clf; hold on;                                   % M(n)
mk(plot(n(A), M(A)*100, "o-b")); mk(plot(n(B), M(B)*100, "s-r")); mk(plot(n(C), M(C)*100, "^-g"));
plot(n(bad), M(bad)*100, "kx", "markersize", 9);
plot(nQ, MQ*100, "m-.", "linewidth", 1.5);
xlabel("n [obr/s]"); ylabel("M [Ncm]"); title("Moment oporowy M = M(n)"); grid on;
xlim([40 300]);
legend([leg, {"Quanser (M = F/k_\\tau)"}], "location", "northwest");

figure(3); clf; hold on;                                   % etaT [g/W]
mk(plot(n(A), etaT(A), "o-b")); mk(plot(n(B), etaT(B), "s-r")); mk(plot(n(C), etaT(C), "^-g"));
plot(cb_n, cb_eta, "k--", "linewidth", 1.5);
xlabel("n [obr/s]"); ylabel("\\eta_T [g/W]"); title("Ciag na wat mocy elektrycznej"); grid on;
legend("11.1 V, V=0", "9.5 V, V=0", "11.1 V, z tunelem", "Cobra", "location", "northeast");

figure(4); clf;                                          % Ct, Cn, eta (lambda)
ok  = valid & Cn > 0;                                      % pomijamy punkty z M <= 0
okv = ok & V > 0;                                          % eta ma sens tylko dla V > 0
subplot(1, 3, 1); plot(lambda(ok), Ct(ok), "bo", "markersize", 7);
xlabel("\\lambda"); ylabel("C_t"); title("Wsp. ciagu"); grid on;
subplot(1, 3, 2); plot(lambda(ok), Cn(ok), "rs", "markersize", 7);
xlabel("\\lambda"); ylabel("C_n"); title("Wsp. momentu"); grid on;
subplot(1, 3, 3); plot(lambda(okv), eta(okv), "g^", "markersize", 7);
xlabel("\\lambda"); ylabel("\\eta"); title("Sprawnosc smigla"); grid on;

figure(5); clf; hold on;                                   % sprawnosci zespolu
mk(plot(n(A), eta_m(A), "o-b")); mk(plot(n(B), eta_m(B), "s-r")); mk(plot(n(C), eta_m(C), "^-g"));
mk(plot(n(C), eta_zn(C), "^--k"));
xlabel("n [obr/s]"); ylabel("sprawnosc [-]"); grid on;
title("Sprawnosc silnika (M\\omega/UI) i zespolu napedowego (TV/UI)");
legend("\\eta_m 11.1 V", "\\eta_m 9.5 V", "\\eta_m 11.1 V, tunel", "\\eta_{zn} (tunel)", "location", "northeast");

figure(6); clf; hold on;                                   % I(n)
mk(plot(n(A), I(A), "o-b")); mk(plot(n(B), I(B), "s-r")); mk(plot(n(C), I(C), "^-g"));
plot(cb_n, cb_I, "k--", "linewidth", 1.5);
xlabel("n [obr/s]"); ylabel("I [A]"); title("Prad pobierany I = I(n)"); grid on;
legend("11.1 V, V=0", "9.5 V, V=0", "11.1 V, z tunelem", "Cobra", "location", "northwest");

names = {"T_n", "M_n", "etaT", "Ct_Cn_eta_lambda", "sprawnosci", "I_n"};
printf("\nZapis wykresow:\n");
if save_figs
  for k = 1:6
    figure(k); save_fig_as(["wykres_" names{k} ".png"], {"-dpng"});
  end
end

if save_pdf
  files = "";
  for k = 1:6
    figure(k);
    fn = ["wykres_" names{k} ".pdf"];
    if save_fig_as(fn, {"-dpdf", "-dpdfcairo", "-dpdfwrite"})
      files = [files " " fn];
    end
  end
  if ~isempty(files)
    [st, ~] = system("which pdfunite");
    if st == 0
      system(["pdfunite" files " wykresy_all.pdf"]);
      printf("  OK  wykresy_all.pdf (pdfunite)\n");
    else
      printf("  --  brak pdfunite (sudo pacman -S poppler) - PDF-y nie zostaly polaczone\n");
    end
  else
    [~, gsout] = system("which gs");
    printf("  Zaden PDF nie powstal. Ghostscript: %s\n", strtrim(gsout));
    printf("  Sprobuj: sudo pacman -S ghostscript\n");
  end
end

if save_table
  fid = fopen("wyniki.csv", "w");
  fprintf(fid, "nr;U[V];PWM[%%];n[1/s];I[A];T[N];M[Nm];Ne[W];etaT[g/W];V[m/s];v_zas[m/s];lambda;Ct;Cn;eta;eta_m;eta_zn\n");
  for k = 1:numel(no)
    fprintf(fid, "%d;%.2f;%.2f;%.2f;%.3f;%.3f;%.5f;%.3f;%.3f;%.3f;%.3f;%.4f;%.5f;%.5f;%.4f;%.4f;%.4f\n", ...
      no(k), U(k), pwm(k), n(k), I(k), T(k), M(k), Ne(k), etaT(k), V(k), v_w(k), ...
      lambda(k), Ct(k), Cn(k), eta(k), eta_m(k), eta_zn(k));
  end
  fclose(fid);
  printf("Zapisano tabele: wyniki.csv\n");
end
