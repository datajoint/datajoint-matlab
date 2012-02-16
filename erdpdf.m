function erdpdf(entity)
assert( strncmpi(computer,'mac',3), 'Has not been tested on a non-Mac')

erd(entity)

set(gcf,'PaperUnits','inches','PaperPosition',[0 0 11 8],'PaperSize',[11 8])
print('-dpdf', './temp_erd')
system('open ./temp_erd.pdf; rm ./temp_erd.pdf');
close(gcf)