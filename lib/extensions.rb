class Float
  def prec(prec)
    ("%.#{prec}f" % self).to_f
  end
end
