clc; clear; close all;
# UWAGA - kod w octave. Żeby działało w matlabie
# trzeba zamienić dlmread w linijce 17 i zamienić na odpowiednie readmatrix
# w przypadku dalszych bledow - powdzenia, chat i w drogę

% ================= constants =================
ro = 1.1975;            % air density [kg/m^3]
g  = 9.81;
nu = 1.52e-5;           % kinematic viscosity of air [m^2/s]
c  = 0.12;              % chord [m]
S  = 0.42 * 0.12;       % wing area [m^2]  (= 0.0504)
scale = 100;            % 100 -> plots of 100*Cz, 100*Cx like the original graph
sc = sprintf("%g", scale);

% ================= data =================
% columns: q alfa beta N -m -T C n l date time temp
dane = dlmread("nike69.dat", "", 2, 0);
dane = real(dane);
dane(:, 5:6) = -dane(:, 5:6);          % sign change: columns 5, 6 -> m, T

q     = g * mean(dane(:,1));           % dynamic pressure [Pa] (mmH2O -> Pa)
alpha = dane(:,2);                     % angle of attack [deg]
N     = dane(:,4);                     % normal force
m     = dane(:,5);                     % moment
T     = dane(:,6);                     % tangential force
n     = dane(:,8);                     % small moment "n" (used by the graded code)

% ================= flow check =================
v  = sqrt(2*q/ro);
Re = v * c / nu;
printf("q = %.1f Pa (0.5*ro*v^2 check: v = %.2f m/s), Re = %.3g\n", q, v, Re);

% ================= forces: rotate to flow axes =================
a  = alpha * pi/180;
z  = N.*cos(a) - T.*sin(a);            % lift
x  = N.*sin(a) + T.*cos(a);            % drag

% ================= coefficients =================
Cz  = z / (q*S);
Cx  = x / (q*S);
K   = Cz ./ Cx;                        % lift-to-drag ratio
Mo  = m * 0.196 * 1.503;               % CHECK these factors in your lab manual
Cmo = Mo / (q*S*c);
Cn  = n / (q*S);
tp  = Cmo ./ Cn;                       % center of pressure (as in the graded code)
tp_plot = tp / c / 65;

% ================= linear range fits (-3 .. 10 deg) =================
lin = alpha >= -3 & alpha <= 10;
pz  = polyfit(alpha(lin), Cz(lin), 1);   alfa0 = -pz(2)/pz(1);   % Cz = 0
pm  = polyfit(alpha(lin), Cmo(lin), 1);                          % dCmo/dalpha
pa  = polyfit(Cz(lin), Cmo(lin), 1);     ta_c = pa(1);           % dCmo/dCz
[Kmax, iK] = max(K);

printf("alfa0 = %.2f deg\n", alfa0);
printf("dCz/dalpha = %.4f 1/deg\n", pz(1));
printf("dCmo/dalpha = %.4f 1/deg\n", pm(1));
printf("ta/c = %.4f  (ta = %.1f mm)\n", ta_c, ta_c*c*1000);
printf("Kmax = %.2f @ %.1f deg\n", Kmax, alpha(iK));

col = [0 0.447 0.741];  fitc = [0.85 0.325 0.098];
lw = 1.4;  ms = 5;
af = linspace(min(alpha), 10, 50);

% ================= figure 1: 6 characteristics =================
f1 = figure("color", "w");

subplot(2,3,1)
plot(alpha, Cx, "o-", "color", col, "linewidth", lw, "markersize", ms);
grid on; xlabel("\\alpha [deg]"); ylabel("C_x"); title("C_x(\\alpha)");

subplot(2,3,2)
plot(alpha, Cz, "o-", "color", col, "linewidth", lw, "markersize", ms); hold on;
plot(af, polyval(pz, af), "--", "color", fitc, "linewidth", 1.2);
yl = ylim; plot([alfa0 alfa0], yl, ":k");
plot(xlim, [0 0], "k-");
grid on; xlabel("\\alpha [deg]"); ylabel("C_z"); title("C_z(\\alpha)");
legend("pomiar", sprintf("dC_z/d\\alpha = %.4f 1/deg", pz(1)), ...
       sprintf("\\alpha_0 = %.2f deg", alfa0), "", "location", "southeast");
hold off

subplot(2,3,3)
plot(alpha, Cmo, "o-", "color", col, "linewidth", lw, "markersize", ms); hold on;
plot(af, polyval(pm, af), "--", "color", fitc, "linewidth", 1.2);
plot(xlim, [0 0], "k-");
grid on; xlabel("\\alpha [deg]"); ylabel("C_{mo}"); title("C_{mo}(\\alpha)");
legend("pomiar", sprintf("dC_{mo}/d\\alpha = %.4f 1/deg", pm(1)), "location", "best");
hold off

subplot(2,3,4)
plot(Cx, Cz, "o-", "color", col, "linewidth", lw, "markersize", ms); hold on;
for i = 1:2:numel(alpha)
  text(Cx(i), Cz(i), sprintf("  %d\\circ", round(alpha(i))), "fontsize", 8);
end
grid on; xlabel("C_x"); ylabel("C_z"); title("Biegunowa C_z(C_x)");
hold off

subplot(2,3,5)
plot(alpha, K, "o-", "color", col, "linewidth", lw, "markersize", ms); hold on;
plot(alpha(iK), Kmax, "p", "markersize", 12, "markerfacecolor", fitc, "markeredgecolor", "k");
text(alpha(iK), Kmax, sprintf("  K_{max} = %.2f @ %.0f\\circ", Kmax, alpha(iK)), ...
     "verticalalignment", "bottom");
plot(xlim, [0 0], "k-");
grid on; xlabel("\\alpha [deg]"); ylabel("C_z/C_x"); title("Doskonalosc C_z/C_x(\\alpha)");
hold off

subplot(2,3,6)
m20 = alpha <= 20;
plot(alpha(m20), tp_plot(m20), "o-", "color", col, "linewidth", lw, "markersize", ms); hold on;
plot([alfa0 alfa0], [-1 1], "--", "color", fitc, "linewidth", 1.2);
plot([min(alpha) 20], [ta_c ta_c], "--", "color", fitc, "linewidth", 1.2);
xlim([min(alpha) 20]); ylim([-1 1]);
grid on; xlabel("\\alpha [deg]"); ylabel("e = t_p/c"); title("Wedrowka srodka parcia");
text(min(alpha)+0.5, ta_c, sprintf(" dC_{mo}/dC_z = %.3f", ta_c), "verticalalignment", "bottom");
hold off

% ================= figure 2: dual axis (Cz, Cx) + Cz/Cx =================
f2 = figure("color", "w");

ax1 = subplot(1,2,1);
h1 = plot(ax1, alpha, scale*Cz, "b-o");
grid(ax1, "on");
xlabel(ax1, "\\alpha [deg]"); ylabel(ax1, [sc " C_z"]);
set(ax1, "ycolor", "b");

ax2 = axes("position", get(ax1, "position"));
h2 = plot(ax2, alpha, scale*Cx, "r-s");
set(ax2, "color", "none", "yaxislocation", "right", ...
         "xlim", get(ax1, "xlim"), "xtick", [], "ycolor", "r");
ylabel(ax2, [sc " C_x"]);
legend([h1 h2], {[sc " C_z"], [sc " C_x"]}, "location", "northwest");

ax3 = subplot(1,2,2);
plot(ax3, alpha, K, "k-o"); grid(ax3, "on");
xlabel(ax3, "\\alpha [deg]"); ylabel(ax3, "C_z / C_x");
legend(ax3, "C_z/C_x", "location", "northwest");

% ================= export (PDF page = figure size, PNG 300 dpi) =================
set(f1, "paperunits", "centimeters", "papersize", [30 18], "paperposition", [0 0 30 18]);
print(f1, "charakterystyki.pdf", "-dpdf");
print(f1, "charakterystyki.png", "-dpng", "-r300");

set(f2, "paperunits", "centimeters", "papersize", [28 11], "paperposition", [0 0 28 11]);
print(f2, "cz_cx_ld.pdf", "-dpdf");
