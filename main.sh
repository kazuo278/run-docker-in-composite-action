#/bin/bash

WORKSPACE="/workdir"
MAVEN_LOCAL_PEPO_PATH="$WORKSPACE/.m2/repository"
ENV_PREFIX="CUSTOM_"

export CUSTOM_EVIL1="aaa hello-world && echo evil"
export CUSTOM_NAME1="-Daaa=vvv -Dfas=csddsf"

echo "ARG CHECK"
ARG1=$1
ARG2=$2
ARG3=$3

# ARGにシークレットが入ってもマスクされる
cat <<EOM
ARG1=$ARG1
ARG2=$ARG2
ARG3=$ARG3
EOM

echo "-----------------------------------------------"

echo "ENV CHECK"
env | sort

echo "-----------------------------------------------"

echo "CREATE ENV FOR CONTAINER"

#ENV_STR1="-e MAVEN_LOCAL_PEPO_PATH=$MAVEN_LOCAL_PEPO_PATH"
ENV_STR1=""
ENV_STR2=""

# for文はIFS(デフォルト スペース、タブ、改行)で区切られ実行される
# これがないと「CUTSOM_ENV=-Daaa=111 -Dbbb=222」などスペースがある文字が来た場合、
# 「CUTSOM_ENV=-Daaa=111」と「-Dbbb=222」の２回ループが実行されてしまう
IFS=$'\n'
for str in $(env | grep -E "^$ENV_PREFIX.+$")
do
  key=$(echo $str | cut -d "=" -f 1)
  new_key=$(echo $key | sed "s/$ENV_PREFIX//")
  value=$(echo $str | sed "s/$key=//")

  # ①引数にkey=valueで渡すパターン
  # valueにインジェクションが指定される可能性がある
  # → printf '%q'でサニタイズすれば回避できそう
  # 以下の通り、「&&」で分割されず、一つの文字列として渡ることを確認
  # ○ホスト側
  # CUSUTOM_EVIL1=aaa hello-world && echo evil
  # ○コンテナ側
  # EVIL1=aaa hello-world && echo evil
  ENV_STR1="-e $(printf '%q' "$new_key"="$value") $ENV_STR1"
  # ENV_STR1="-e $(printf '%q' "$new_key")=\"$(printf '%q' "$value")\" $ENV_STR1"
  # ↑ 「$(printf '%q' "$value")」を「"」で括ると、「$(printf '%q' "$value")」が
  #　"-Dskip.Test=true\ -Dhttp.proxyHost=xxx"であった場合に「\」がそのまま環境変数値に残ってしまう。
  printf '%q ' $ENV_STR1

  # ②環境変数に登録して、keyだけを渡すパターン
  # 元のコンテナの環境変数を上書きしてしまう可能性がある(CUSTOM_PATHとか)ので、①を優先する
  # ①でシークレットが見えちゃうようならこっちも試す
  eval "export $(printf '%q' "$new_key")=\"$(printf '%q' "$value")\""
  ENV_STR2="-e \"$(printf '%q' $new_key)\" $ENV_STR2"
done

# ①,②のどちらのパターンもシークレットはマスクされた
echo ENV_STR1="\"$ENV_STR1\""
echo ENV_STR2="\"$ENV_STR2\""

echo "-----------------------------------------------"

echo "CREATE OPTION FOR CONTAINER"

OPTS="$ARG1"
OPTS="$OPTS $ARG2"
OPTS="$OPTS $ARG3"

# シークレットがマスクされる
echo OPTS=\"$OPTS\"

echo "-----------------------------------------------"

#echo "docker CHECK"
# docker run --rm --entrypoint bash "$ENV_STR1" centos:7 $OPTS
# ↑ $ENV_STR="-e name1=aaa -e name2=bbb"であった場合にname1="aaa -e name2=bbb"と扱われる
# docker run --rm --entrypoint env $ENV_STR1 centos:7
# ↑ evalがないと、$ENV_STR="-e name1=aaa -e name2=bbb"であった場合にname1="aaa -e name2=bbb"と扱われる
echo "$ENV_STR1"
echo docker run --rm --entrypoint env $ENV_STR1 centos:7 $OPTS

eval docker run --rm --entrypoint env $ENV_STR1 centos:7 $OPTS
# evalを使っていても printf '%q'でサニタイズすれば問題ない
# 以下の通り、「&&」で分割されず、一つの文字列として渡ることを確認
# ○ホスト側
# CUSUTOM_EVIL1=aaa hello-world && echo evil
# ○コンテナ側
# EVIL1=aaa hello-world && echo evil